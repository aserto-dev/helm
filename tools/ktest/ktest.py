#!/usr/bin/env python3
"""Test Helm Charts in k3s"""

import logging
import subprocess
from contextlib import contextmanager, ExitStack
from os import path
from typing import Iterator, Sequence

import click
import git
import yaml

from kubernetes import config

from model import Deployment, Spec, Test
from namespace import Namespace

logger = logging.getLogger("k3stest")

COLOR_HARNESS = "blue"
COLOR_STEP = "magenta"
COLOR_ERROR = "red"


def echo(emoji: str, heading: str, msg: str = "", *, cl=COLOR_HARNESS, nl=False):
    out = f"{emoji} {click.style(heading, fg=cl)} {msg}"
    if nl:
        out = f"\n{out}\n"
    click.echo(out)


class Runner:
    def __init__(self, test: Test, spec_path: str):
        self.test = test
        self.spec_path = spec_path
        self.git_root = git_root(__file__)

    def run(self):
        with self.new_namespace(self.test.name) as ns:
            self.set_image_pull_secret(ns)

            for secret in self.test.secrets:
                echo("🔒", "Creating secret:", secret.name)
                ns.create_secret(secret)

            for config_map in self.test.config_maps:
                echo("📝", "Creating config map:", config_map.name)
                ns.create_config_map(config_map)

            for deployment in self.test.deployments:
                echo("🗺️", "Installing chart:", deployment.chart)
                self.deploy_chart(deployment, ns)

            self.wait_for_deployments(self.test.deployments, ns)

            echo("✅", "Deployment complete.", nl=True)

            with ExitStack() as stack:
                for deployment in self.test.deployments:
                    echo(
                        "🔀",
                        "Forwarding ports:",
                        f"{deployment.chart} - {deployment.ports}",
                    )
                    stack.enter_context(ns.forward(deployment.chart, deployment.ports))

                    try:
                        self.execute_steps()
                        echo("✅", "Tests complete.", nl=True)
                    except:
                        echo("🚨", "Test failed.", nl=True, cl=COLOR_ERROR)
                        pod = ns.svc_pod(deployment.chart)
                        echo("📋", "Pod logs:", pod)
                        ns.logs(pod)
                        click.echo()
                        raise
                    finally:
                        self.execute_cleanup()

    def deploy_chart(self, deployment: Deployment, ns: Namespace):
        chart_path = path.join(self.git_root, "charts", deployment.chart)
        ns.helm("dep", "build", chart_path)
        ns.helm(
            "install",
            deployment.chart,
            chart_path,
            "-f",
            path.join(self.spec_path, deployment.values),
        )

    def wait_for_deployments(self, deployments: Sequence[Deployment], ns: Namespace):
        for deployment in deployments:
            pod = ns.svc_pod(deployment.chart)
            try:
                echo("⏳", "Waiting for pod:", pod)
                ns.wait(pod)
            except:
                echo(
                    "🚨",
                    "Error waiting for deployment:",
                    deployment.chart,
                    nl=True,
                    cl=COLOR_ERROR,
                )
                echo("📋", "Pod logs:", pod)
                ns.logs(pod)
                click.echo()
                raise

    def execute_steps(self):
        echo("🏃", "Running tests", nl=True)
        for step in self.test.run:
            echo("🧪", step, cl=COLOR_STEP)
            self.subprocess(step)

    def execute_cleanup(self):
        echo("🧹", "Running cleanup", nl=True)
        for step in self.test.cleanup:
            echo("🧹", step, cl=COLOR_STEP)
            try:
                self.subprocess(step)
            except:
                pass

    def set_image_pull_secret(self, ns: Namespace):
        if self.test.pull_secret:
            ns.kubectl(
                "create",
                "secret",
                "docker-registry",
                "ghcr-creds",
                "--docker-server=https://ghcr.io",
                "--docker-username=gh_user",
                f"--docker-password={path.expandvars(self.test.pull_secret)}",
            )

    @staticmethod
    def subprocess(args: str, check=True):
        subprocess.run(
            args=args,
            shell=True,
            check=check,
            timeout=30,
        )

    @staticmethod
    @contextmanager
    def new_namespace(name: str) -> Iterator["Namespace"]:
        ns = Namespace(name)
        if ns.ns_exists():
            logger.info("namespace '%s' already exists. deleting it...", name)
            ns.delete_ns()

        echo("🐳", "Creating namespace:", name)
        ns.create_ns()

        yield ns

        echo("🐳", "Deleting namespace:", name)
        ns.delete_ns()


@click.command()
@click.argument("specfile", type=click.File())
def main(specfile):
    """Run tests in a kubernetes cluster.

    SPECFILE: path to a YAML file with test definitions.
    """

    init_logging(logging.DEBUG)
    config.load_kube_config()

    spec = Spec(**yaml.safe_load(specfile))
    spec_path = path.dirname(specfile.name)

    for test in spec.tests:
        echo("🏁", "Starting test:", test.name)
        Runner(test, spec_path).run()


def git_root(from_path: str) -> str:
    repo = git.Repo(from_path, search_parent_directories=True)
    return repo.git.rev_parse("--show-toplevel")


def init_logging(level=logging.INFO):
    loggers = (
        logging.getLogger(name)
        for name in logging.root.manager.loggerDict
        if name.startswith("k3test")
    )
    for logger in loggers:
        init_logger(logger, level)


def init_logger(logger: logging.Logger, level=logging.INFO):
    logger.setLevel(level)

    # create console handler and set level to debug
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)

    # create formatter
    formatter = logging.Formatter(
        "%(asctime)s - %(levelname)s - %(name)s - %(message)s"
    )

    # add formatter to ch
    ch.setFormatter(formatter)

    # add ch to logger
    logger.addHandler(ch)


if __name__ == "__main__":
    main()
