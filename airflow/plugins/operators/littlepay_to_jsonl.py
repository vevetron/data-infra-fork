import csv
import gzip
import json
import os
from io import StringIO
from typing import ClassVar, List

import pendulum
from calitp_data_infra.storage import (
    PartitionedGCSArtifact,
    fetch_all_in_partition,
    get_fs,
)
from operators.littlepay_raw_sync import RawLittlepayFileExtract
from pydantic.main import BaseModel
from tqdm import tqdm
from tqdm.contrib.logging import logging_redirect_tqdm

from airflow.models import BaseOperator

LITTLEPAY_RAW_BUCKET = os.getenv("CALITP_BUCKET__LITTLEPAY_RAW")
LITTLEPAY_PARSED_BUCKET = os.getenv("CALITP_BUCKET__LITTLEPAY_PARSED")


class LittlepayFileJSONL(PartitionedGCSArtifact):
    bucket: ClassVar[str] = LITTLEPAY_PARSED_BUCKET
    partition_names: ClassVar[List[str]] = ["instance", "extract_filename", "ts"]
    extract: RawLittlepayFileExtract

    @property
    def table(self) -> str:
        return self.extract.table

    @property
    def instance(self) -> str:
        return self.extract.instance

    @property
    def extract_filename(self) -> str:
        return self.extract.filename

    @property
    def ts(self) -> pendulum.DateTime:
        return self.extract.ts


# TODO: outcome type; track unknown file types
class LittlepayFileParsingOutcome(BaseModel):
    raw_file: RawLittlepayFileExtract
    parsed_file: LittlepayFileJSONL


class LittlepayParsingJobResult(PartitionedGCSArtifact):
    bucket: ClassVar[str] = LITTLEPAY_PARSED_BUCKET
    table: ClassVar[str] = "parse_littlepay_job_result"
    partition_names: ClassVar[List[str]] = ["instance", "dt"]
    instance: str
    dt: pendulum.Date


def parse_raw_file(file: RawLittlepayFileExtract, fs) -> LittlepayFileParsingOutcome:
    # mostly stolen from the Schedule job, we could probably abstract this
    # assume this is PSV for now, but we could sniff the delimiter
    filename, extension = os.path.splitext(file.filename)
    assert extension == ".psv"
    with fs.open(file.path) as f:
        reader = csv.DictReader(
            StringIO(f.read().decode("utf-8-sig")),
            restkey="calitp_unknown_fields",
            delimiter="|",
        )
    lines = [
        {**row, "_line_number": line_number}
        for line_number, row in enumerate(reader, start=1)
    ]
    jsonl_file = LittlepayFileJSONL(
        extract=file,
        filename=f"{filename}.jsonl.gz",
    )
    jsonl_file.save_content(
        content=gzip.compress("\n".join(json.dumps(line) for line in lines).encode()),
        fs=fs,
    )
    return LittlepayFileParsingOutcome(
        raw_file=file,
        parsed_file=jsonl_file,
    )


class LittlepayToJSONL(BaseOperator):
    template_fields = ()

    def __init__(
        self,
        *args,
        instance: str,
        **kwargs,
    ):
        self.instance = instance
        super().__init__(**kwargs)

    def execute(self, context):
        assert LITTLEPAY_RAW_BUCKET is not None and LITTLEPAY_PARSED_BUCKET is not None

        fs = get_fs()
        outcomes: List[LittlepayFileParsingOutcome] = []

        # TODO: this could be worth splitting into separate tasks
        entities = [
            "authorisations",
            "customer-funding-source",
            "device-transaction-purchases",
            "device-transactions",
            "micropayment-adjustments",
            "micropayment-device-transactions",
            "micropayments",
            "product-data",
            "refunds",
            "settlements",
        ]

        with logging_redirect_tqdm():
            for entity in tqdm(entities):
                files_to_process: List[RawLittlepayFileExtract]
                # This is not very efficient but it should be approximately 1 file per day
                # since the instance began
                files_to_process, _, _ = fetch_all_in_partition(
                    cls=RawLittlepayFileExtract,
                    table=entity,
                    partitions={
                        "instance": self.instance,
                    },
                    verbose=True,
                )
                print(f"found {len(files_to_process)} files to check")

                dt = context["execution_date"].date()

                print(f"filtering files created on {dt}")

                files_to_process = [
                    file
                    for file in files_to_process
                    if file.ts.date() == context["execution_date"].date()
                ]

                file: RawLittlepayFileExtract
                for file in tqdm(files_to_process, desc=entity):
                    outcomes.append(parse_raw_file(file, fs=fs))

        LittlepayParsingJobResult(
            instance=self.instance,
            dt=dt,
            filename="results.jsonl",
        ).save_content("\n".join(o.json() for o in outcomes).encode(), fs=fs)
