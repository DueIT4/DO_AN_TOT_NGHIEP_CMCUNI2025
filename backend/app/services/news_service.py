import time
from typing import Optional, List, Dict, Any, Tuple
import httpx
from app.core.config import settings


class NewsService:
    def __init__(self):
        self.api_key = getattr(settings, "NEWS_API_KEY", None) or getattr(
            settings, "NEWSAPI_API_KEY", None
        )
        if not self.api_key:
            raise RuntimeError("Missing NEWS_API_KEY in setting/.env")

        self.base = (
            getattr(settings, "NEWSAPI_BASE_URL", "https://newsapi.org/v2")
            or "https://newsapi.org/v2"
        ).rstrip("/")
        self.timeout = 12

        # cache theo query (5 phút)
        self._cache: Dict[str, Tuple[float, Any]] = {}
        self._cache_ttl_sec = 300

        # ✅ "last good" cache: luôn có tin thật để trả về nếu fetch lỗi/rỗng
        self._last_good: Dict[str, Tuple[float, List[Dict[str, Any]]]] = {}
        self._last_good_ttl_sec = 72 * 3600  # giữ 72 giờ

        # ✅ allowlist nguồn chính thống/hợp pháp
        self.allowed_domains = set(
            [
                "mard.gov.vn",
                "khuyennongvn.gov.vn",
                "nongnghiep.vn",
                "nhandan.vn",
                "vietnamplus.vn",
                "vtv.vn",
                "vov.vn",
                "tuoitre.vn",
                "thanhnien.vn",
                "dantri.com.vn",
            ]
        )

        # ⛔ blacklist
        self.blocked_domains = set(["bbc.co.uk", "bbc.com"])

        # ✅ lớp phụ: chặn theo keyword nhạy cảm (bạn có thể chỉnh theo tiêu chí)
        # Lưu ý: keyword chỉ là "đai an toàn" thêm; allowlist vẫn là quan trọng nhất.
        self.blocked_keywords = [
            # ví dụ chung chung về nội dung bạo lực/khủng bố/phi pháp...
            "khủng bố",
            "chế tạo bom",
            "mua bán vũ khí",
            "ma túy",
            "lật đổ",
            "kích động bạo loạn",
        ]

    def _is_allowed_url(self, url: str) -> bool:
        if not url:
            return False
        try:
            host = (httpx.URL(url).host or "").lower()
        except Exception:
            return False

        # blacklist
        for d in self.blocked_domains:
            dd = d.lower()
            if host == dd or host.endswith("." + dd):
                return False

        # allowlist
        for d in self.allowed_domains:
            dd = d.lower()
            if host == dd or host.endswith("." + dd):
                return True
        return False

    def _is_blocked_text(self, title: str, description: str) -> bool:
        text = f"{title} {description}".lower()
        for kw in self.blocked_keywords:
            if kw.lower() in text:
                return True
        return False

    def _cache_get(self, key: str):
        item = self._cache.get(key)
        if not item:
            return None
        ts, value = item
        if time.time() - ts > self._cache_ttl_sec:
            self._cache.pop(key, None)
            return None
        return value

    def _cache_set(self, key: str, value: Any):
        self._cache[key] = (time.time(), value)

    def _last_good_get(self, key: str) -> Optional[List[Dict[str, Any]]]:
        item = self._last_good.get(key)
        if not item:
            return None
        ts, value = item
        if time.time() - ts > self._last_good_ttl_sec:
            self._last_good.pop(key, None)
            return None
        return value

    def _last_good_set(self, key: str, value: List[Dict[str, Any]]):
        if value:
            self._last_good[key] = (time.time(), value)

    async def fetch_agri_news(
        self,
        q: str,
        lang: Optional[str] = "vi",
        page_size: int = 10,
        sort_by: str = "publishedAt",
    ) -> List[Dict[str, Any]]:
        """
        ✅ Luôn cố gắng trả về danh sách tin:
        - Ưu tiên: cache 5 phút
        - Nếu fetch NewsAPI ok: lưu last_good và trả
        - Nếu fetch lỗi/rỗng: trả last_good (tin thật lần gần nhất)
        """

        # key theo query
        cache_key = (
            f"agri:{q}|{lang}|{page_size}|{sort_by}|"
            f"{','.join(sorted(self.allowed_domains))}|{','.join(sorted(self.blocked_domains))}"
        )

        cached = self._cache_get(cache_key)
        if cached is not None and len(cached) > 0:
            return cached

        params = {
            "q": q,
            "pageSize": str(max(1, min(page_size, 30))),
            "sortBy": sort_by,
            "apiKey": self.api_key,
        }
        if lang:
            params["language"] = lang

        # ⚠️ Khuyến nghị: bỏ domains=... để tăng khả năng có tin (NewsAPI đôi khi index k đủ)
        # An toàn vẫn đảm bảo vì ta lọc lại bằng _is_allowed_url()
        # Nếu bạn muốn giữ chặt ngay từ đầu, uncomment dòng dưới:
        # params["domains"] = ",".join(sorted(self.allowed_domains))

        url = f"{self.base}/everything"

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                res = await client.get(url, params=params)
        except Exception:
            # lỗi mạng -> trả last_good
            last = self._last_good_get(cache_key)
            return last or []

        if res.status_code != 200:
            last = self._last_good_get(cache_key)
            return last or []

        data = res.json()
        if data.get("status") != "ok":
            last = self._last_good_get(cache_key)
            return last or []

        articles = data.get("articles") or []
        mapped: List[Dict[str, Any]] = []

        for a in articles:
            item = {
                "title": a.get("title") or "(Không có tiêu đề)",
                "description": a.get("description") or "",
                "url": a.get("url") or "",
                "imageUrl": a.get("urlToImage"),
                "source": (a.get("source") or {}).get("name") or "",
                "publishedAt": a.get("publishedAt") or "",
            }

            # 1) lọc domain
            if not self._is_allowed_url(item["url"]):
                continue

            # 2) lọc keyword nhạy cảm (lớp phụ)
            if self._is_blocked_text(item["title"], item["description"]):
                continue

            mapped.append(item)

            # đủ số lượng thì dừng sớm
            if len(mapped) >= page_size:
                break

        # Nếu mapped rỗng -> trả last_good
        if not mapped:
            last = self._last_good_get(cache_key)
            return last or []

        # Lưu cache + last_good
        self._cache_set(cache_key, mapped)
        self._last_good_set(cache_key, mapped)
        return mapped
