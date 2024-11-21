#!/usr/bin/env python3
"""Test Helm Charts in k3s"""

import logging
import subprocess
from contextlib import contextmanager, ExitStack
from os import path
from typing import Iterator

import click
import git
import yaml

from kubernetes import config

from model import Spec, Test
from namespace import Namespace

logger = logging.getLogger("k3stest")

COLOR_HARNESS = "blue"
COLOR_STEP = "magenta"
COLOR_CLEANUP = "cyan"


class Runner:
    def __init__(self, test: Test, spec_path: str):
        self.test = test
        self.spec_path = spec_path
        self.git_root = git_root(__file__)

    def run(self):
        with self.new_namespace(self.test.name) as ns:
            self.set_image_pull_secret(ns)

            for secret in self.test.secrets:
                click.echo(
                    f"🔒 {click.style("Creating secret:", fg=COLOR_HARNESS)} {secret.name}"
                )
                ns.create_secret(secret)

            for deployment in self.test.deployments:
                click.echo(
                    f"🗺️ {click.style("Installing chart:", fg=COLOR_HARNESS)} {deployment.chart}"
                )
                ns.helm(
                    "install",
                    deployment.chart,
                    path.join(self.git_root, "charts", deployment.chart),
                    "-f",
                    path.join(self.spec_path, deployment.values),
                )

            for deployment in self.test.deployments:
                ns.wait(ns.svc_pod(deployment.chart))

            with ExitStack() as stack:
                for deployment in self.test.deployments:
                    click.echo(
                        f"🔀 {click.style("Forwarding port(s):", fg=COLOR_HARNESS)} "
                        f"{deployment.chart} - {deployment.ports}"
                    )
                    stack.enter_context(ns.forward(deployment.chart, deployment.ports))

                    click.echo("\n✅ Deployment complete.\n")
                    try:
                        self.execute_steps()

                        click.echo("\n✅ Tests complete.\n")
                    finally:
                        self.execute_cleanup()

    def execute_steps(self):
        click.echo(f"🏃 {click.style("Running tests", fg=COLOR_HARNESS)}\n")
        for step in self.test.run:
            click.echo(f"🧪 {click.style(step, fg=COLOR_STEP)}")
            self.subprocess(step)

    def execute_cleanup(self):
        click.echo(f"\n🧹 {click.style("Running cleanup", fg=COLOR_HARNESS)}\n")
        for step in self.test.cleanup:
            click.echo(f"🧽 {click.style(step, fg=COLOR_STEP)}")
            self.subprocess(step, check=False)

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
        )

    @staticmethod
    @contextmanager
    def new_namespace(name: str) -> Iterator["Namespace"]:
        ns = Namespace(name)
        if ns.ns_exists():
            logger.info("namespace '%s' already exists. deleting it...", name)
            ns.delete_ns()

        click.echo(f"🐳 {click.style("Creating namespace:", fg=COLOR_HARNESS)} {name}")
        ns.create_ns()

        yield ns

        click.echo(
            f"\n🐳 {click.style("Deleting namespace:", fg=COLOR_HARNESS)} {name}"
        )
        ns.delete_ns()


@click.command()
@click.argument("specfile", type=click.File())
def main(specfile):
    """Run tests in a kubernetes cluster.

    SPECFILE: path to a YAML file with test definitions.
    """

    init_logger(logging.DEBUG)
    config.load_kube_config()

    spec = Spec(**yaml.safe_load(specfile))
    spec_path = path.dirname(specfile.name)

    for test in spec.tests:
        click.echo(f"🏁 {click.style('Starting test:', fg=COLOR_HARNESS)} {test.name}")
        Runner(test, spec_path).run()


def git_root(from_path: str) -> str:
    repo = git.Repo(from_path, search_parent_directories=True)
    return repo.git.rev_parse("--show-toplevel")


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
