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

logger = logging.getLogger("k3test.namespace")


class Namespace:
    def __init__(self, namespace: str):
        self.namespace = namespace
        self.cluster = client.CoreV1Api()

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
        args = " ".join(
            ("kubectl", "-n", self.namespace, "port-forward", pod) + port_mapping
        )
        logger.debug("port-forward: %s", args)
        proc = subprocess.Popen(
            args=args,
            shell=True,
            stdout=subprocess.DEVNULL,
        )

        time.sleep(1.5)

        try:
            yield proc
        finally:
            logger.debug("terminating port-forward: %s", svc)
            proc.terminate()
            try:
                proc.wait(1)
            except subprocess.TimeoutExpired:
                logger.info("timeout expired. killing port-forward: %s", svc)
                proc.kill()
            logger.debug("port-forward terminated: %s", svc)

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

        return proc.stdout.decode()

    def helm(self, *args, check=True):
        args = ("helm", "-n", self.namespace) + args
        return subprocess.run(args=" ".join(args), shell=True, check=check)


def kubectl(*args, check: bool = True, capture_output: bool = False):
    args = ("kubectl",) + args
    return subprocess.run(
        args=" ".join(args), check=check, shell=True, capture_output=capture_output
    )
