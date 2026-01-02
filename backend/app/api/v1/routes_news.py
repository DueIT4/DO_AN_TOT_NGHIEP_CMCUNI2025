from fastapi import APIRouter, HTTPException, Query
from app.services.news_service import NewsService

router = APIRouter(prefix="/news", tags=["News"])

# Khởi tạo service duy nhất
news_service = NewsService()

@router.get("")
async def get_news(
    q: str = Query('"nông nghiệp" OR "nông dân" OR "trồng trọt" OR "cây trồng" OR "nông sản"'),
    lang: str = Query("vi"),
    pageSize: int = Query(10, ge=1, le=30),
):
    try:
        # Gọi hàm fetch từ NewsService đã có bộ lọc allowlist/blacklist
        articles = await news_service.fetch_agri_news(
            q=q, 
            lang=lang, 
            page_size=pageSize
        )
        
        # Nếu service trả về rỗng, trả về lỗi nhẹ để FE biết
        if not articles:
            return []
            
        return articles # Trả về list Map trực tiếp cho FE dễ đọc
    except Exception as e:
        print(f"Error fetching news: {e}")
        raise HTTPException(status_code=502, detail="Không thể lấy tin tức từ server")