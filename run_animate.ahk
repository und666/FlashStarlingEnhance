; Searching Adobe Animate Window
SetTitleMatchMode, 2
IfWinExist, main_AN.fla
{
    WinActivate ; 激活（聚焦）该窗口
    Send, ^{Enter} ; 发送 Ctrl + Enter 组合键
}
else
{
    MsgBox, Not found Adobe Animate Window
}
return