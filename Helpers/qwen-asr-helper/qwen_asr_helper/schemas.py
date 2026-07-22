from pydantic import BaseModel


class HealthResponse(BaseModel):
    ok: bool
    engine: str


class ModelStatusResponse(BaseModel):
    installed: bool
    loaded: bool
    loading: bool
    downloading: bool | None = None
    progress: float | None = None
    phase: str | None = None
    error_code: str | None = None
    operation_id: str | None = None
    updated_at: float | None = None
    model_id: str
    model_path: str | None = None


class TranscribeResponse(BaseModel):
    text: str
