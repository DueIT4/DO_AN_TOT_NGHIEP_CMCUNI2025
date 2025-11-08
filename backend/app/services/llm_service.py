from typing import Optional

class LLMService:
    """
    Service để sinh giải thích về bệnh cây bằng LLM.
    Hiện tại dùng template-based, có thể mở rộng tích hợp LLM thật sau.
    """
    
    def __init__(self):
        pass
    
    async def generate_explanation(
        self, 
        disease_name: str, 
        confidence: float
    ) -> str:
        """
        Sinh giải thích về bệnh dựa trên tên bệnh và độ chính xác.
        
        Args:
            disease_name: Tên bệnh (ví dụ: "pomelo_leaf_miner")
            confidence: Độ chính xác (0-1)
            
        Returns:
            Chuỗi giải thích về bệnh
        """
        # Chuyển đổi tên bệnh sang tiếng Việt dễ đọc
        disease_display = self._format_disease_name(disease_name)
        
        # Xác định mức độ chắc chắn
        if confidence >= 0.9:
            certainty = "rất cao"
        elif confidence >= 0.7:
            certainty = "cao"
        elif confidence >= 0.5:
            certainty = "trung bình"
        else:
            certainty = "thấp"
        
        # Tạo giải thích dựa trên loại bệnh
        explanation = self._get_disease_explanation(disease_name, disease_display, certainty, confidence)
        
        return explanation
    
    def _format_disease_name(self, name: str) -> str:
        """Chuyển đổi tên bệnh từ format snake_case sang tiếng Việt."""
        name_map = {
            "pomelo_fruit_healthy": "Quả bưởi khỏe mạnh",
            "pomelo_fruit_scorch": "Quả bưởi bị cháy nắng",
            "pomelo_leaf_healthy": "Lá bưởi khỏe mạnh",
            "pomelo_leaf_miner": "Lá bưởi bị sâu đục lá",
            "pomelo_leaf_yellowing": "Lá bưởi bị vàng lá"
        }
        return name_map.get(name, name.replace("_", " ").title())
    
    def _get_disease_explanation(
        self, 
        disease_name: str, 
        disease_display: str, 
        certainty: str, 
        confidence: float
    ) -> str:
        """Tạo giải thích chi tiết về bệnh."""
        
        explanations = {
            "pomelo_fruit_healthy": f"""
Kết quả phân tích cho thấy quả bưởi đang trong tình trạng khỏe mạnh. 
Độ chính xác của dự đoán là {certainty} ({confidence*100:.1f}%). 
Quả bưởi không có dấu hiệu bệnh tật, có thể tiếp tục chăm sóc bình thường.
            """,
            "pomelo_fruit_scorch": f"""
Kết quả phân tích phát hiện quả bưởi có dấu hiệu bị cháy nắng (sunscald).
Độ chính xác: {certainty} ({confidence*100:.1f}%).

Triệu chứng: Vỏ quả bị cháy, có thể xuất hiện vết nâu hoặc đen do tiếp xúc trực tiếp với ánh nắng mặt trời quá mức.

Khuyến nghị:
- Che chắn quả bằng túi giấy hoặc lưới che nắng
- Tăng cường tưới nước vào sáng sớm
- Cân nhắc tỉa cành để tạo bóng mát cho quả
            """,
            "pomelo_leaf_healthy": f"""
Kết quả phân tích cho thấy lá bưởi đang khỏe mạnh.
Độ chính xác: {certainty} ({confidence*100:.1f}%).
Lá có màu xanh đậm, không có dấu hiệu bệnh tật. Tiếp tục chăm sóc cây bình thường.
            """,
            "pomelo_leaf_miner": f"""
Kết quả phân tích phát hiện lá bưởi bị sâu đục lá (leaf miner).
Độ chính xác: {certainty} ({confidence*100:.1f}%).

Triệu chứng: Lá xuất hiện các đường ngoằn ngoèo màu trắng hoặc nâu do ấu trùng sâu đục bên trong lá.

Khuyến nghị điều trị:
- Cắt bỏ và tiêu hủy các lá bị nhiễm nặng
- Phun thuốc trừ sâu có hoạt chất Abamectin hoặc Spinosad
- Sử dụng bẫy dính màu vàng để bắt ruồi trưởng thành
- Tăng cường bón phân hữu cơ để cây khỏe mạnh hơn
            """,
            "pomelo_leaf_yellowing": f"""
Kết quả phân tích phát hiện lá bưởi bị vàng lá.
Độ chính xác: {certainty} ({confidence*100:.1f}%).

Nguyên nhân có thể:
- Thiếu dinh dưỡng (đặc biệt là đạm, sắt, magie)
- Thừa nước hoặc thiếu nước
- Bệnh vàng lá gân xanh (greening)
- Nhiễm nấm hoặc vi khuẩn

Khuyến nghị:
- Kiểm tra độ ẩm đất và điều chỉnh tưới nước phù hợp
- Bón phân cân đối, đặc biệt bổ sung vi lượng
- Xử lý bằng thuốc trừ nấm nếu có dấu hiệu nhiễm nấm
- Nếu nghi ngờ bệnh vàng lá gân xanh, cần cách ly và xử lý ngay
            """
        }
        
        default_explanation = f"""
Kết quả phân tích: {disease_display}
Độ chính xác: {certainty} ({confidence*100:.1f}%).

Vui lòng tham khảo thêm thông tin từ chuyên gia để có biện pháp xử lý phù hợp.
        """
        
        return explanations.get(disease_name, default_explanation).strip()

