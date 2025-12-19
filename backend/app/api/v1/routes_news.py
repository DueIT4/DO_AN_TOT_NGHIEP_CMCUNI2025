from fastapi import APIRouter, HTTPException, Query
from app.services.news_service import NewsService

router = APIRouter(prefix="/news", tags=["News"])

# tạo singleton service (đơn giản)
news_service = NewsService()


@router.get("")
async def get_news(
    q: str = Query(
        '"nông nghiệp" OR "nông dân" OR "trồng trọt" OR "cây trồng" OR "nông sản"'
    ),
    lang: str = Query("vi"),
    pageSize: int = Query(10, ge=1, le=30),
):
    try:
        items = await news_service.fetch_agri_news(q=q, lang=lang, page_size=pageSize)
        return {
            "status": "ok",
            "count": len(items),
            "articles": items,
            "policy": {
                "mode": "whitelist",
                "allowedDomains": sorted(list(news_service.allowed_domains)),
            },
        }
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"News fetch failed: {e}")
