from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.pagesizes import A4

OUT=Path('output/pdf'); OUT.mkdir(parents=True,exist_ok=True)
pdfmetrics.registerFont(TTFont('Chinese','C:/Windows/Fonts/simhei.ttf'))
c=canvas.Canvas(str(OUT/'施工日志打印模板_客户确认.pdf'),pagesize=A4)
c.setTitle('施工日志 A4 打印模板 · 客户确认稿')
W,H=A4; L=43; R=W-43; width=R-L
blue='#20558A'; ink='#252B33'; gray='#657080'
def text(x,y,s,size=11,color=ink):
    c.setFillColor(HexColor(color)); c.setFont('Chinese',size); c.drawString(x,y,s)
def rect(x,y,w,h,fill='#F2F6FA',stroke='#D7E0E9'):
    c.setFillColor(HexColor(fill)); c.setStrokeColor(HexColor(stroke)); c.rect(x,y,w,h,fill=1,stroke=1)
def base(page,title,sub):
    text(L,H-57,title,23,blue); text(L,H-82,sub,10,gray)
    c.setStrokeColor(HexColor(blue)); c.line(L,H-96,R,H-96)
    c.setStrokeColor(HexColor('#D7E0E9')); c.line(L,45,R,45)
    text(L,29,'模板示例 · 仅供版式确认，非真实施工记录',9,gray)
    text(R-66,29,f'第 {page} / 3 页',9,gray)
def section(y,title,lines):
    rect(L,y-28,width,28); text(L+12,y-19,title,12,blue)
    yy=y-51
    for line in lines:
        text(L+12,yy,line,11); yy-=23
    return yy-12

base(1,'项目施工日志汇编','A4 竖版 · 日期范围导出 · 客户确认稿 V2')
text(L,710,'工程名称：示例项目 · 综合楼装修工程',15)
text(L,679,'导出范围：2026-10-07 至 2026-10-13（共 7 天）')
text(L,656,'导出内容：所选日期内，各主管已提交的施工日志')
text(L,633,'排序方式：日志日期升序，同一天按提交主管排列')
section(598,'目录示例',[
    '日志日期          提交主管             内容',
    '2026-10-13        张主管               正文与昨日考勤',
    '2026-10-13        张主管               施工照片（6 张）',
])
section(449,'打印与阅读说明',[
    '每份日志独立开始；正文过长时自动续页，不截断内容。',
    '施工照片按上传顺序排列，保留原有水印，完整显示。',
    '考勤数据为提交日志时的快照，并明确标注考勤日期。',
    '正式导出包含范围内全部已提交日志；本稿只展示一份样例。',
    '未提交日期不生成空白日志，实际目录按导出内容生成。',
])
text(L,205,'建议：多份日志附目录，单份日志可省略目录页。',11,blue)
c.showPage()
base(2,'施工日志','示例项目 · 综合楼装修工程')
rect(L,655,width,76)
text(L+12,708,'日志日期：2026-10-13  星期二',13)
text(L+12,684,'提交主管：张主管     提交时间：2026-10-13 18:05')
text(L+12,666,'状态：已提交',10,gray)
y=section(635,'今日施工进度',[
    '1. 二层大厅天花安装累计完成 78%，今日完成龙骨校正。',
    '2. 二层风机盘管控制线穿线累计完成 99%，待末端核验。',
    '3. 南侧办公室天花腻子刮涂累计完成 60%。',
    '现场说明：材料按计划到场，已完成作业面清理。',
])
y=section(y,'明日施工计划',[
    '1. 二层大厅天花安装计划累计完成 80%。',
    '2. 二层风机盘管控制线穿线完成并进行检查。',
    '3. 南侧办公室天花腻子刮涂计划累计完成 90%。',
])
y=section(y,'昨日考勤摘要 · 2026-10-12',[
    '应出勤 11 人    实际打卡 10 人    暂停免卡 1 人',
    '待处理 1 人 / 1 条    已处理节点 2 个',
    '未出工申请待审批 0 人',
    '工时 80.0 小时    加班 0.0 小时    工数 10.0',
])
text(L+12,y,'说明：按人员去重；昨日考勤不代表今日施工人数。',9,gray)
text(L+12,y-18,'此处为提交时快照，后续异常处理不会改写本日志。',9,gray)
c.showPage()
base(3,'施工照片','2026-10-13 · 张主管 · 共 6 张（照片版式示例）')
gap=14; cw=(width-gap)/2; ch=192
for i in range(6):
    x=L+(i%2)*(cw+gap); top=724-(i//2)*(ch+16)
    rect(x,top-ch,cw,ch,'#FFFFFF')
    rect(x+8,top-ch+34,cw-16,ch-42,'#EEF2F5')
    text(x+25,top-71,f'施工现场照片 {i+1}',13,gray)
    text(x+25,top-96,'正式导出置入原照片',10,gray)
    text(x+25,top-114,'等比缩放 · 不裁切',10,gray)
    rect(x+15,top-ch+43,cw-30,28,'#FFFFFF')
    text(x+20,top-ch+60,'原照片水印保留',9,blue)
    text(x+20,top-ch+47,'项目 / 拍摄时间 / 拍摄人',8,gray)
    text(x+10,top-ch+14,f'图片 {i+1}  ·  示例作业面',10)
text(L,77,'说明：占位框用于确认排版；正式 PDF 使用已提交的水印照片。',9,gray)
c.save()
print(str(OUT/'施工日志打印模板_客户确认.pdf'))
