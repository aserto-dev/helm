from dataclasses import dataclass
from pydantic import BaseModel


@dataclass
class Secret:
    name: str
    values: dict[str, str]


@dataclass
class Deployment:
    chart: str
    values: str
    ports: dict[int, int]


@dataclass
class Test:
    name: str
    pull_secret: str
    secrets: list[Secret]
    deployments: list[Deployment]
    run: list[str]
    cleanup: list[str]


class Spec(BaseModel):
    tests: list[Test]
