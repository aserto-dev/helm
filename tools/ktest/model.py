from dataclasses import dataclass
from pydantic import BaseModel


@dataclass
class ConfigMapKey:
    name: str
    file: str


@dataclass
class ConfigMap:
    name: str
    keys: list[ConfigMapKey]


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
    config_maps: list[ConfigMap]
    deployments: list[Deployment]
    run: list[str]
    cleanup: list[str]


class Spec(BaseModel):
    tests: list[Test]
