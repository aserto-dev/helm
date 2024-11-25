from dataclasses import dataclass
from pydantic import BaseModel, Field


@dataclass
class ConfigMapKey:
    name: str
    file: str


@dataclass
class ConfigMap:
    name: str
    keys: list[ConfigMapKey]


class Secret(BaseModel):
    name: str
    values: dict[str, str] = Field(default_factory=lambda: {})
    files: dict[str, str] = Field(default_factory=lambda: {})


class Deployment(BaseModel):
    chart: str
    values: str = Field(default="")
    ports: dict[int, int]


class Test(BaseModel):
    name: str
    pull_secret: str = Field(default="")
    secrets: list[Secret] = Field(default_factory=lambda: [])
    config_maps: list[ConfigMap] = Field(default_factory=lambda: [])
    deployments: list[Deployment]
    run: list[str]
    cleanup: list[str] = Field(default_factory=lambda: [])


class Spec(BaseModel):
    tests: list[Test]
