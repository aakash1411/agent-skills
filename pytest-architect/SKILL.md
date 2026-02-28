---
name: pytest-architect
description: Designs and generates production-grade Python test suites using pytest. Use this skill whenever a Python project needs tests created or restructured, fixtures are getting messy, AWS services need mocking, or async/PySpark/Lambda handlers need test coverage. Activate when someone says "create tests", "test structure", "pytest fixtures", "mock AWS", "test Lambda", "test data pipeline", or when a new Python service is being scaffolded. Don't wait to be asked: if Python code is being written without a corresponding test structure, this skill should shape how tests are organized from the start.
---

# Pytest Architect

Production-grade pytest test suite design for enterprise Python services and data pipelines.

## Directory structure

```
project/
├── src/
│   └── <package>/
│       ├── __init__.py
│       ├── handlers/       # Lambda/API handlers
│       ├── services/       # Business logic
│       ├── repositories/   # Data access
│       └── transforms/     # Data pipeline transforms
├── tests/
│   ├── conftest.py         # Root fixtures (shared across all tests)
│   ├── unit/
│   │   ├── conftest.py     # Unit-specific fixtures (mocks, stubs)
│   │   ├── test_services.py
│   │   ├── test_handlers.py
│   │   └── test_transforms.py
│   ├── integration/
│   │   ├── conftest.py     # Integration fixtures (LocalStack, test DB)
│   │   └── test_repositories.py
│   └── e2e/
│       ├── conftest.py     # E2E fixtures (real AWS, test account)
│       └── test_workflows.py
├── pyproject.toml          # pytest config section
└── conftest.py             # Top-level (rarely used; root fixtures preferred in tests/)
```

## Fixture design patterns

### Layered conftest

- `tests/conftest.py`: shared across all test types (env setup, common data builders).
- `tests/unit/conftest.py`: mock factories, stub clients, in-memory repos.
- `tests/integration/conftest.py`: LocalStack clients, test database connections.

### Factory fixtures

```python
@pytest.fixture
def make_user():
    """Factory fixture for creating test users with defaults."""
    def _make(name="test", email="test@example.com", **overrides):
        defaults = {"name": name, "email": email, "active": True}
        defaults.update(overrides)
        return User(**defaults)
    return _make
```

### AWS mock fixtures (using moto)

```python
@pytest.fixture
def s3_client():
    with mock_aws():
        client = boto3.client("s3", region_name="us-east-1")
        client.create_bucket(Bucket="test-bucket")
        yield client

@pytest.fixture
def dynamodb_table():
    with mock_aws():
        client = boto3.resource("dynamodb", region_name="us-east-1")
        table = client.create_table(
            TableName="test-table",
            KeySchema=[{"AttributeName": "pk", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "pk", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        yield table
```

### PySpark test fixtures

```python
@pytest.fixture(scope="session")
def spark():
    """Session-scoped SparkSession for transform tests."""
    return (
        SparkSession.builder
        .master("local[1]")
        .appName("test")
        .config("spark.sql.shuffle.partitions", "1")
        .getOrCreate()
    )

@pytest.fixture
def sample_df(spark):
    """Small deterministic DataFrame for transform testing."""
    data = [{"id": 1, "value": "a"}, {"id": 2, "value": "b"}]
    return spark.createDataFrame(data)
```

## Parametrize patterns

```python
@pytest.mark.parametrize("input_val,expected", [
    ("valid@email.com", True),
    ("invalid", False),
    ("", False),
    (None, False),
])
def test_email_validation(input_val, expected):
    assert validate_email(input_val) == expected
```

Use `pytest.param(..., id="descriptive-name")` for complex parameter sets.

## Marker conventions

```ini
# pyproject.toml
[tool.pytest.ini_options]
markers = [
    "unit: fast isolated tests",
    "integration: tests with external dependencies",
    "e2e: end-to-end tests against real services",
    "slow: tests taking >5s",
    "aws: tests requiring AWS credentials or moto",
]
```

Run selectively: `pytest -m "unit and not slow"`.

## Testing async code

```python
import pytest

@pytest.mark.asyncio
async def test_async_handler():
    result = await handler(event={}, context={})
    assert result["statusCode"] == 200
```

Requires `pytest-asyncio`. Set `asyncio_mode = "auto"` in config for less boilerplate.

## Lambda handler testing pattern

```python
def test_lambda_handler(s3_client):
    """Test Lambda with mocked AWS services."""
    # Arrange: put test data in mocked S3
    s3_client.put_object(Bucket="test-bucket", Key="input.json", Body=b'{"key": "value"}')

    # Act: invoke handler with synthetic event
    event = {"Records": [{"s3": {"bucket": {"name": "test-bucket"}, "object": {"key": "input.json"}}}]}
    result = handler(event, None)

    # Assert
    assert result["statusCode"] == 200
```

## Coverage configuration

```ini
# pyproject.toml
[tool.coverage.run]
source = ["src"]
omit = ["*/tests/*", "*/migrations/*", "*/__pycache__/*"]

[tool.coverage.report]
fail_under = 80
show_missing = true
exclude_lines = [
    "pragma: no cover",
    "if TYPE_CHECKING:",
    "if __name__ == .__main__.:",
]
```

## Rules

- Don't mix unit and integration tests in the same file: they run at different speeds, need different setup, and mixing them makes selective execution (e.g., `pytest -m unit`) impossible.
- Keep fixtures minimal: create only what the test needs. Over-specified fixtures make tests brittle when unrelated implementation details change.
- Use `scope="session"` for expensive resources (SparkSession, DB connections) and `scope="function"` for everything else: function scope prevents test pollution.
- Mock at the boundary (AWS clients, HTTP clients, DB connections), not internal functions. Mocking internals couples tests to implementation rather than behavior.
- Keep test data deterministic: random values make failures non-reproducible and waste debugging time.
- For data pipelines: test with small DataFrames (5-20 rows). Production-scale data in tests is slow, expensive, and doesn't catch more bugs.

## Edge cases

- **Fixture dependency cycles:** restructure fixtures to avoid circular deps; use factory pattern.
- **Moto missing API coverage:** fall back to `botocore.stub.Stubber` for unsupported operations.
- **PySpark test isolation:** use `function`-scoped DataFrames but `session`-scoped SparkSession.
- **Async fixture cleanup:** use `yield` in async fixtures with proper teardown.
- **Environment variable leakage:** use `monkeypatch.setenv` in fixtures; never set globals.
- **Large test suites:** use `pytest-xdist` for parallel execution: `pytest -n auto`.
- **Flaky tests:** mark with `@pytest.mark.flaky(reruns=3)` using `pytest-rerunfailures`; track and fix.
