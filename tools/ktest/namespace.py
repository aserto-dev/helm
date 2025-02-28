import logging
import signal
import subprocess
import time

from contextlib import contextmanager
from functools import lru_cache
from os import path
from typing import Mapping

from kubernetes import client
from kubernetes.client.rest import ApiException

from model import ConfigMap, Secret

logger = logging.getLogger(__name__)


class Namespace:
    def __init__(self, namespace: str):
        self.namespace = namespace
        self.cluster = client.CoreV1Api()

    @staticmethod
    def current_context() -> str:
        proc = kubectl("config", "current-context", capture_output=True)
        return proc.stdout.decode().strip()

    def create_ns(self):
        kubectl("create", "namespace", self.namespace)

    def delete_ns(self):
        kubectl("delete", "namespace", self.namespace, "--wait=true")

    def ns_exists(self):
        try:
            self.cluster.read_namespace(self.namespace)
            return True
        except ApiException as e:
            if e.status != 404:
                raise

        return False

    def create_secret(self, secret: Secret):
        literals = (
            f"--from-literal={k}={path.expandvars(v)}" for k, v in secret.values.items()
        )
        files = (
            f"--from-file={k}={path.expandvars(v)}" for k, v in secret.files.items()
        )
        self.kubectl(
            "create",
            "secret",
            "generic",
            secret.name,
            *literals,
            *files,
        )

    def create_config_map(self, config_map: ConfigMap):
        keys = (
            f"--from-file={key.name}={path.expandvars(key.file)}"
            for key in config_map.keys
        )
        self.kubectl("create", "configmap", config_map.name, *keys)

    def kubectl(self, *args):
        kubectl(*args, "-n", self.namespace)

    def wait(self, pod: str):
        self.kubectl(
            "wait",
            "--for=condition=ready",
            "--timeout=30s",
            "pod",
            pod,
        )

    def logs(self, pod: str):
        self.kubectl("logs", pod)

    @contextmanager
    def forward(self, svc: str, ports: Mapping[int, int]):
        pod = self.svc_pod(svc)
        port_mapping = tuple(f"{k}:{v}" for k, v in ports.items())
        logger.debug("port-mapping: %s", port_mapping)
        args = (kctl_path(), "-n", self.namespace, "port-forward", pod) + port_mapping
        logger.debug("port-forward: %s", args)
        proc = subprocess.Popen(
            args=args,
            stdout=subprocess.DEVNULL,
        )

        time.sleep(1.5)

        try:
            yield proc
        finally:
            logger.debug("terminating port-forward: %s", svc)

            def ctrl_c():
                proc.send_signal(signal.SIGINT)

            for stop in (ctrl_c, proc.terminate, proc.kill):
                logger.debug("attempting to '%s' port-forward: %s", stop.__name__, svc)
                stop()
                try:
                    proc.wait(timeout=15)
                    logger.debug("port-forward exited: %s", svc)
                    break
                except subprocess.TimeoutExpired:
                    logger.info("timeout expired waiting for: %s", svc)

            if proc.returncode is None:
                logger.debug("unable to stop port-forwarding: %s", svc)
            else:
                logger.debug(
                    "port-forward terminated: %s. exit code: %d", svc, proc.returncode
                )

    @lru_cache(maxsize=32)
    def svc_pod(self, svc: str) -> str:
        proc = kubectl(
            "get",
            "pods",
            "--namespace",
            self.namespace,
            "-l",
            f"app.kubernetes.io/name={svc},app.kubernetes.io/instance={svc}",
            "-o",
            "jsonpath='{.items[0].metadata.name}'",
            capture_output=True,
        )

        if proc.returncode != 0:
            proc.check_returncode()

        return proc.stdout.decode().strip("''")

    def helm(self, *args, check=True):
        args = ("helm", "-n", self.namespace) + args
        return subprocess.run(args=" ".join(args), shell=True, check=check)


@lru_cache(maxsize=1)
def kctl_path():
    return (
        subprocess.run(
            args="which kubectl",
            shell=True,
            check=True,
            capture_output=True,
        )
        .stdout.decode()
        .strip()
    )


def kubectl(*args, check: bool = True, capture_output: bool = False):
    args = (kctl_path(),) + args
    return subprocess.run(args=args, check=check, capture_output=capture_output)
