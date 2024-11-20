#!/usr/bin/env python3
"""Test Helm Charts in k3s"""

import logging
import random
import signal
import string
import subprocess
import time
from contextlib import contextmanager
from functools import lru_cache
from typing import Iterator, Mapping

from kubernetes import client, config
from kubernetes.client.rest import ApiException

logger = logging.getLogger("k3stest")

TOPAZ = "~/aserto-dev/topaz/dist/topaz_darwin_arm64/topaz"
TENANT_ID = "3dbaa470-9c7e-11ef-bf36-00fcb2a75cb1"
TENANT_NAME = "test"


def main():
    init_logger(logging.DEBUG)
    config.load_kube_config()

    read_key, write_key = keygen(), keygen()

    with new_namespace("directory") as ns:
        ns.run(
            "create",
            "secret",
            "docker-registry",
            "ghcr-creds",
            "--docker-server=https://ghcr.io",
            "--docker-username=gh_user",
            "--docker-password=$GITHUB_TOKEN",
        )

        ns.run(
            "create",
            "secret",
            "generic",
            "pg-credentials",
            "--from-literal=password=",
            "--from-literal=username=postgres",
        )

        ns.run(
            "create",
            "secret",
            "generic",
            f"{TENANT_NAME}-tenant-keys",
            f"--from-literal=reader={read_key}",
            f"--from-literal=writer={write_key}",
        )

        ns.helm(
            "install",
            "directory",
            "charts/directory",
            "-f",
            "test/directory/directory.values.yaml",
        )

        ns.wait(ns.svc_pod("directory"))

        with ns.forward("directory", {8282: 8282, 2222: 2222}):
            subprocess.run(
                args="ssh -p 2222 localhost provision root-keys",
                shell=True,
                check=True,
            )

            subprocess.run(
                args=f"ssh -p 2222 localhost provision tenant {TENANT_NAME} --id {TENANT_ID}",
                shell=True,
                check=True,
            )

            subprocess.run(
                args=f"{TOPAZ} ds get manifest -H localhost:8282 --tenant-id {TENANT_ID} "
                f"--api-key {read_key} --stdout --plaintext",
                shell=True,
                check=True,
            )


@contextmanager
def new_namespace(name: str) -> Iterator["Namespace"]:
    ns = Namespace(name)
    if ns.exists():
        logger.info("namespace '%s' already exists. deleting it...", name)
        ns.delete()

    ns.create()

    yield ns


class Namespace:
    def __init__(self, namespace: str):
        self.namespace = namespace
        self.cluster = client.CoreV1Api()

    def create(self):
        self.kubectl("create", "namespace", self.namespace)

    def delete(self):
        self.kubectl("delete", "namespace", self.namespace, "--wait=true")

    def exists(self):
        try:
            self.cluster.read_namespace(self.namespace)
            return True
        except ApiException as e:
            print("read ns error:", e)

        return False

    def run(self, *args):
        self.kubectl(*args, "-n", self.namespace)

    def wait(self, pod: str):
        self.run(
            "wait",
            "--for=condition=ready",
            "--timeout=30s",
            "pod",
            pod,
        )

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
        )

        time.sleep(1.5)

        try:
            yield proc
        finally:
            logger.debug("terminating port-forward")
            proc.send_signal(signal.SIGINT)
            proc.wait()
            logger.debug("port-forward terminated")

    @lru_cache(maxsize=32)
    def svc_pod(self, svc: str) -> str:
        proc = self.kubectl(
            "get",
            "pods",
            "--namespace",
            "directory",
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

    @staticmethod
    def kubectl(*args, check: bool = True, capture_output: bool = False):
        args = ("kubectl",) + args
        return subprocess.run(
            args=" ".join(args), check=check, shell=True, capture_output=capture_output
        )


def keygen() -> str:
    return "".join(random.choices(string.ascii_letters + string.digits, k=32))


def init_logger(level=logging.INFO):
    logger.setLevel(level)

    # create console handler and set level to debug
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)

    # create formatter
    formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")

    # add formatter to ch
    ch.setFormatter(formatter)

    # add ch to logger
    logger.addHandler(ch)


if __name__ == "__main__":
    main()
