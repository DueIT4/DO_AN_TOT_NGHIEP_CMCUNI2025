# # app/services/usage_limit.py
# from datetime import date
# from fastapi import HTTPException
# from sqlalchemy.orm import Session

# from app.models.predict_usage import PredictUsage

# MAX_FREE_PREDICT_PER_DAY = 3


# def check_predict_limit(db: Session, client_key: str):
#     today = date.today()

#     usage = (
#         db.query(PredictUsage)
#         .filter_by(client_key=client_key, date=today)
#         .first()
#     )

#     # Đã có record hôm nay
#     if usage:
#         if usage.count >= MAX_FREE_PREDICT_PER_DAY:
#             raise HTTPException(
#                 status_code=429,
#                 detail={
#                     "code": "LIMIT_REACHED",
#                     "message": (
#                         "Bạn đã dùng hết 3 lượt dự đoán miễn phí trên web hôm nay. "
#                         "Vui lòng tải ứng dụng ZestGuard trên CH Play để tiếp tục sử dụng không giới hạn."
#                     ),
#                 },
#             )
#         usage.count += 1
#         db.commit()
#         return

#     # Chưa có record, tạo mới
#     usage = PredictUsage(
#         client_key=client_key,
#         date=today,
#         count=1,
#     )
#     db.add(usage)
#     db.commit()
