/* THÊM CỘT MỚI
*/
--- Thêm cột LOAIKH vào bảng KHACHHANG ---
ALTER TABLE KHACHHANG ADD LOAIKH VARCHAR(40)

---Thêm cột khuyến mãi ---
ALTER TABLE CTHD ADD KHUYENMAI DECIMAL(6,2)

/* THÊM RÀNG BUỘC BẰNG CHECK VÀ TRIGGER VÀ TỰ ĐỘNG CẬP NHẬT
*/
--- Thêm ràng buộc vào cột DVT bảng SANPHAM chỉ được có giá trị sau đây: 'cay', 'hop', 'cai', 'quyen', 'chuc'  ---
ALTER TABLE SANPHAM ADD CONSTRAINT CK_DONVI CHECK( DVT IN ('cay', 'hop', 'cai', 'quyen', 'chuc'))

--- Thêm ràng buộc vào cột GIA bảng SANPHAM với giá >= 500 ---
ALTER TABLE SANPHAM ADD CONSTRAINT CK_GIA CHECK( GIA >= 500)

--- Thêm ràng buộc vào cột SL bảng CTHD với SL >= 1  ---
ALTER TABLE CTHD ADD CONSTRAINT CK_SL CHECK ( SL >= 1)

--- Thêm ràng buộc vào cột NGDK bảng KHACHHANG với NGDK > NGSINH  ---
ALTER TABLE KHACHHANG ADD CONSTRAINT CK_NGDK CHECK ( NGDK > NGSINH)

--- Thêm ràng buộc cột NGHD bảng HOADON với NGHD >= NGDK
CREATE TRIGGER TG_ThemNGHD
ON HOADON
FOR INSERT
AS
BEGIN
	IF EXISTS ( SELECT 1 
				FROM INSERTED INS 
				LEFT JOIN KHACHHANG KH 
				ON INS.MAKH = KH.MAKH 
				WHERE INS.NGHD < KH.NGDK)
	BEGIN
		PRINT N'Ngày hóa đơn phải lớn bằng ngày đăng ký khách hàng'
		ROLLBACK TRANSACTION
	END
END

INSERT INTO HOADON
VALUES
(1025, '20051030', 'KH03', 'NV01', 200000)

--- Khi khách hàng mua hàng thì KHUYENMAI là 5% nếu số lượng từ 30 đến 50, 10% nếu số lượng từ 50 trở lên ---
CREATE TRIGGER TG_CapNhatKhuyenMai ON CTHD
FOR INSERT, UPDATE
AS
BEGIN
	UPDATE CTHD
	SET KHUYENMAI = 
	CASE 
		WHEN SL > 30 AND SL <= 50 THEN 0.05
		WHEN SL > 50 THEN 0.10 END
END
GO

--- Kiểm tra ---
INSERT INTO CTHD ( SOHD, MASP, SL)
VALUES 
(1002, 'BC02', 50)

--- Không cho phép xoá một lúc nhiều hơn một sản phẩm ở bảng SANPHAM ---
CREATE TRIGGER TG_XoaHangHoa
ON SANPHAM
FOR DELETE
AS
BEGIN
	IF ( (SELECT COUNT(*) FROM DELETED) > 1)
		PRINT N'Khong được xóa một lúc nhiều sản phẩm'
		ROLLBACK TRANSACTION
END

DELETE FROM SANPHAM
WHERE MASP IN ('BB01', 'BB02')

--- Không cho phép xoá các dòng trong CTHD có SOHD còn trong bảng HOADON ---
CREATE TRIGGER TG_XoaCTHD
ON CTHD
FOR DELETE
AS
BEGIN
	IF EXISTS (SELECT 1 
				FROM DELETED
				WHERE SOHD IN (
						SELECT SOHD
						FROM HOADON)
	)
	BEGIN
		PRINT N'Mã hóa đơn không được xóa'
		ROLLBACK TRANSACTION
	END
END
GO
--- Kiểm tra ---
DELETE FROM CTHD
WHERE SOHD = 1002 

/* IN DANH SÁCH THEO YÊU CẦU
*/

--- In ra danh sách các khách hàng (MAKH, HOTEN) đã mua hàng trong ngày 1/1/2007 ---
SELECT *
FROM KHACHHANG KH
JOIN HOADON HD
ON KH.MAKH = HD.MAKH
WHERE NGHD = '20070101'

--- Tìm các số hóa đơn mua cùng lúc 2 sản phẩm có mã số “BB01” và “BB02”, mỗi sản phẩm mua với số lượng từ 10 đến 20 ---
SELECT SOHD
FROM CTHD 
WHERE MASP = 'BB01' AND ( SL >=10 AND SL<=20)
INTERSECT 
SELECT SOHD 
FROM CTHD
WHERE MASP ='BB02' AND ( SL >=10 AND SL<=20)

--- In ra danh sách các sản phẩm (MASP,TENSP) do “Trung Quoc” sản xuất không bán được trong năm 2006. ---
SELECT MASP, TENSP
FROM SANPHAM
WHERE NUOCSX = 'Trung Quoc'
AND MASP NOT IN 
(
	SELECT SP.MASP
	FROM SANPHAM SP 
	JOIN CTHD 
	on SP.MASP = CTHD.MASP  
	JOIN HOADON HD 
	on CTHD.SOHD = HD.SOHD
	WHERE YEAR(NGHD) = 2006 AND NUOCSX = 'Trung Quoc'
)

--- In ra danh sách 3 khách hàng có doanh số cao nhất (sắp xếp theo kiểu xếp hạng). ---
SELECT TOP 3	KH.MAKH, 
				KH.HOTEN,
				SUM(HD.TRIGIA) TINHDOANHTHU
FROM KHACHHANG KH
JOIN HOADON HD
ON KH.MAKH = HD.MAKH
GROUP BY KH.MAKH, KH.HOTEN
ORDER BY TINHDOANHTHU DESC

--- Tìm 5 sản phẩm (MASP, TENSP) có tổng số lượng bán ra thấp nhất trong năm 2006 ----
SELECT TOP 5	SP.MASP, 
				SP.TENSP,
				SUM(CT.SL) SOLUONG
FROM SANPHAM SP
JOIN CTHD CT
ON SP.MASP = CT.MASP
GROUP BY SP.MASP, SP.TENSP
ORDER BY SUM(CT.SL) ASC

/* TẠO PROCEDURE ĐỂ HIỆN THỊ VÀ CẬP NHẬT DỮ LIỆU
*/
--- Hiển thị danh các khách hàng đã mua hàng trong ngày chỉ định (ngày là tham số truyền vào) ---
CREATE PROCEDURE SP_HienThiKhachHang
(@Ngay date)
AS
BEGIN
	IF NOT EXISTS (
			SELECT 1
			FROM KHACHHANG KH
			JOIN HOADON HD
			ON KH.MAKH = HD.MAKH
			WHERE HD.NGHD = @Ngay)
	BEGIN
		PRINT N'Khách hàng không mua hàng vào ngày này'
	END
	ELSE
	BEGIN
		SELECT KH.MAKH, KH.HOTEN
		FROM KHACHHANG KH
		JOIN HOADON HD
		ON KH.MAKH = HD.MAKH
		WHERE HD.NGHD = @Ngay
	END
END
GO

EXEC SP_HienThiKhachHang '20061016'
GO

--- Hiển thị danh sách 5 khách hàng có tổng trị giá các đơn hàng lớn nhất ---
CREATE PROCEDURE SP_HienThi5KhachHang
AS
BEGIN
	SELECT TOP 5	KH.MAKH, 
					KH.HOTEN,
					SUM(HD.TRIGIA) TONGGIATRI
	FROM KHACHHANG KH
	JOIN HOADON HD
	ON KH.MAKH = HD.MAKH
	GROUP BY KH.MAKH, KH.HOTEN
	ORDER BY SUM(HD.TRIGIA) DESC
END
GO

EXEC SP_HienThi5KhachHang

--- Hiển thị danh sách 10 mặt hàng có số lượng bán lớn nhất. ---
CREATE PROCEDURE SP_HienThi10SP
AS
BEGIN
	SELECT TOP 10	SP.MASP, 
					SP.TENSP,
					SUM(CT.SL) TONGSOLUONG
	FROM SANPHAM SP
	JOIN CTHD CT
	ON SP.MASP = CT.MASP
	JOIN HOADON HD
	ON HD.SOHD = CT.SOHD
	GROUP BY SP.MASP, SP.TENSP
	ORDER BY TONGSOLUONG DESC
END
GO

EXEC SP_HienThi10SP

--- Cập nhật cột Khuyến mãi như sau: Khuyến mãi 5% thành tiền nếu số lượng 30 đến 50, 10% thành tiền nếu số lượng lớn hơn 50. ---
CREATE PROCEDURE SP_UpdateKhuyenMai
AS
BEGIN
	UPDATE CTHD
	SET KHUYENMAI = 
	CASE 
		WHEN SL > 30 AND SL <= 50 THEN 0.05
		WHEN SL > 50 THEN 0.10 END
END
GO

EXEC SP_UpdateKhuyenMai
GO

--- Check table ---
SELECT * FROM CTHD

--- Tính trị giá cho mỗi hoá đơn ---

CREATE PROCEDURE SP_GiaTriDonHang
AS
BEGIN
	SELECT	HD.SOHD, 
			SUM(SP.GIA*CT.SL) TONGGIATRI
	FROM SANPHAM SP
	JOIN CTHD CT
	ON SP.MASP = CT.MASP
	JOIN HOADON HD
	ON CT.SOHD = HD.SOHD
	GROUP BY HD.SOHD
	ORDER BY TONGGIATRI DESC
END
GO

EXEC SP_GiaTriDonHang
GO

--- Cập nhật cho cột Loại khách hàng: là VIP nếu tổng thành tiền trong năm lớn hơn hoặc bằng 5 trăm ngàn ---

CREATE PROCEDURE USP_KhachHangVIP
AS
BEGIN
	UPDATE KHACHHANG
	SET LoaiKH = 'VIP'
	WHERE MaKH IN
		(
		SELECT MAKH FROM
			(SELECT	KH.MAKH,
					SUM(HD.TRIGIA) ThanhTien	
			FROM HOADON HD
			JOIN KHACHHANG KH
			ON HD.MAKH = KH.MaKH	
			GROUP BY KH.MaKH
			HAVING SUM(HD.TRIGIA) >= 500000
			) AS Cus_tab
		)	
END
GO

EXEC USP_KhachHangVIP
GO

--- Check table ---
SELECT * FROM KHACHHANG