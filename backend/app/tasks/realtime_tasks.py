from app.tasks.celery_app import celery_app


@celery_app.task(name="realtime.aggregate_analytics")
def aggregate_analytics_task(session_id: int) -> None:
    _ = session_id


@celery_app.task(name="realtime.process_recording")
def process_recording_task(session_id: int) -> None:
    _ = session_id


@celery_app.task(name="realtime.delete_recording")
def delete_recording_task(session_id: int) -> None:
    _ = session_id
