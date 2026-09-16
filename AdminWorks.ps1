if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    if (-not $scriptPath -and $MyInvocation.MyCommand.Definition) { $scriptPath = $MyInvocation.MyCommand.Definition }
    if ($scriptPath -and (Test-Path $scriptPath)) {
        $psHost = if ($PSVersionTable.PSEdition -eq "Core") { "pwsh.exe" } else { "powershell.exe" }
        Start-Process $psHost -ArgumentList "-NoProfile", "-File `"$scriptPath`"" -Verb RunAs
        exit
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "AdminWorks Pro requires Administrator privileges.`nPlease launch PowerShell as Administrator and run the script.",
            "Administrator Rights Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        exit
    }
}
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$script:AppVersion = "6.1"
$script:OSBuild    = [Environment]::OSVersion.Version.Build
if ($script:OSBuild -lt 22000) {
    [System.Windows.Forms.MessageBox]::Show(
        "AdminWorks Pro v$($script:AppVersion) is exclusively designed for Windows 11 (Build 22000 or higher).`n`nDetected Windows Build: $script:OSBuild`nThis application cannot run on Windows 10 or earlier versions.",
        "AdminWorks Pro - Windows 11 Required",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Stop
    )
    exit
}

if (-not ('NativeMethods' -as [type])) {
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
using System.Runtime.InteropServices;

public class NativeMethods {
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode, ExactSpelling = true)] public static extern int SetWindowTheme(IntPtr h, string s, string l);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("shcore.dll")] public static extern int SetProcessDpiAwareness(int a);
    [DllImport("user32.dll")] public static extern int SendMessage(IntPtr h, int m, int w, int l);
    [DllImport("user32.dll")] public static extern bool ReleaseCapture();
    [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr h, int a, ref int v, int s);
    [DllImport("dwmapi.dll")] public static extern int DwmExtendFrameIntoClientArea(IntPtr h, ref MARGINS m);
    [DllImport("user32.dll")] public static extern void ShowScrollBar(IntPtr h, int b, bool s);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
    [DllImport("user32.dll")] public static extern bool TrackMouseEvent(ref TRACKMOUSEEVENT lpEventTrack);

    [StructLayout(LayoutKind.Sequential)]
    public struct TRACKMOUSEEVENT {
        public int cbSize;
        public int dwFlags;
        public IntPtr hwndTrack;
        public int dwHoverTime;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MARGINS {
        public int cxLeftWidth, cxRightWidth, cyTopHeight, cyBottomHeight;
        public MARGINS(int l, int r, int t, int b) {
            cxLeftWidth = l; cxRightWidth = r; cyTopHeight = t; cyBottomHeight = b;
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left, Top, Right, Bottom;
        public int Width { get { return Right - Left; } }
        public int Height { get { return Bottom - Top; } }
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct NCCALCSIZE_PARAMS {
        public RECT rgrc0, rgrc1, rgrc2;
        public IntPtr lppos;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MEMORYSTATUSEX {
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX lpBuffer);
}

public class AdminWorksForm : Form {
    public Control MaximizeButton { get; set; }
    public Control MinimizeButton { get; set; }
    public Control CloseButton { get; set; }
    public Control HeaderControl { get; set; }
    public Control SearchPill { get; set; }
    public Control TitleSub { get; set; }
    public Control UpdateBadge { get; set; }
    public Color CloseHoverColor { get; set; }
    public Color ButtonHoverColor { get; set; }
    public Color TextMutedColor { get; set; }

    private bool _trackingMouse = false;

    private void UpdateCaptionHover(Point screenPt) {
        if (CloseButton != null && !CloseButton.IsDisposed && CloseButton.Visible) {
            bool over = CloseButton.ClientRectangle.Contains(CloseButton.PointToClient(screenPt));
            CloseButton.BackColor = over ? CloseHoverColor : Color.Transparent;
            CloseButton.ForeColor = over ? Color.White : TextMutedColor;
        }
        if (MaximizeButton != null && !MaximizeButton.IsDisposed && MaximizeButton.Visible) {
            bool over = MaximizeButton.ClientRectangle.Contains(MaximizeButton.PointToClient(screenPt));
            MaximizeButton.BackColor = over ? ButtonHoverColor : Color.Transparent;
            MaximizeButton.ForeColor = over ? Color.White : TextMutedColor;
        }
        if (MinimizeButton != null && !MinimizeButton.IsDisposed && MinimizeButton.Visible) {
            bool over = MinimizeButton.ClientRectangle.Contains(MinimizeButton.PointToClient(screenPt));
            MinimizeButton.BackColor = over ? ButtonHoverColor : Color.Transparent;
            MinimizeButton.ForeColor = over ? Color.White : TextMutedColor;
        }
    }

    private void ResetCaptionHover() {
        if (CloseButton != null && !CloseButton.IsDisposed) {
            CloseButton.BackColor = Color.Transparent;
            CloseButton.ForeColor = TextMutedColor;
        }
        if (MaximizeButton != null && !MaximizeButton.IsDisposed) {
            MaximizeButton.BackColor = Color.Transparent;
            MaximizeButton.ForeColor = TextMutedColor;
        }
        if (MinimizeButton != null && !MinimizeButton.IsDisposed) {
            MinimizeButton.BackColor = Color.Transparent;
            MinimizeButton.ForeColor = TextMutedColor;
        }
    }

    protected override CreateParams CreateParams {
        get {
            CreateParams cp = base.CreateParams;
            cp.Style |= 0x00040000; // WS_THICKFRAME
            cp.Style |= 0x00010000; // WS_MAXIMIZEBOX
            cp.Style |= 0x00020000; // WS_MINIMIZEBOX
            cp.Style |= 0x00080000; // WS_SYSMENU
            cp.Style |= 0x02000000; // WS_CLIPCHILDREN
            return cp;
        }
    }

    protected override void WndProc(ref Message m) {
        const int WM_NCCALCSIZE    = 0x0083;
        const int WM_NCHITTEST     = 0x0084;
        const int WM_NCLBUTTONDOWN = 0x00A1;
        const int WM_NCLBUTTONUP   = 0x00A2;
        const int WM_NCMOUSEMOVE   = 0x00A0;
        const int WM_NCMOUSELEAVE  = 0x02A2;

        if (m.Msg == WM_NCMOUSEMOVE) {
            if (!_trackingMouse) {
                NativeMethods.TRACKMOUSEEVENT tme = new NativeMethods.TRACKMOUSEEVENT();
                tme.cbSize = Marshal.SizeOf(typeof(NativeMethods.TRACKMOUSEEVENT));
                tme.dwFlags = 0x00000010 /* TME_NONCLIENT */ | 0x00000002 /* TME_LEAVE */;
                tme.hwndTrack = this.Handle;
                NativeMethods.TrackMouseEvent(ref tme);
                _trackingMouse = true;
            }
            int mx = unchecked((short)(long)m.LParam);
            int my = unchecked((short)((long)m.LParam >> 16));
            UpdateCaptionHover(new Point(mx, my));
        }
        else if (m.Msg == WM_NCMOUSELEAVE) {
            _trackingMouse = false;
            ResetCaptionHover();
        }

        if (m.Msg == WM_NCCALCSIZE && m.WParam != IntPtr.Zero) {
            if (this.WindowState == FormWindowState.Maximized) {
                NativeMethods.NCCALCSIZE_PARAMS nsp = (NativeMethods.NCCALCSIZE_PARAMS)Marshal.PtrToStructure(m.LParam, typeof(NativeMethods.NCCALCSIZE_PARAMS));
                Screen scr = Screen.FromHandle(m.HWnd);
                nsp.rgrc0.Left   = scr.WorkingArea.Left;
                nsp.rgrc0.Top    = scr.WorkingArea.Top;
                nsp.rgrc0.Right  = scr.WorkingArea.Right;
                nsp.rgrc0.Bottom = scr.WorkingArea.Bottom;
                Marshal.StructureToPtr(nsp, m.LParam, false);
            }
            m.Result = IntPtr.Zero;
            return;
        }

        if (m.Msg == WM_NCHITTEST) {
            int x = unchecked((short)(long)m.LParam);
            int y = unchecked((short)((long)m.LParam >> 16));
            Point screenPt = new Point(x, y);

            if (TitleSub != null && !TitleSub.IsDisposed && TitleSub.Visible) {
                if (TitleSub.ClientRectangle.Contains(TitleSub.PointToClient(screenPt))) {
                    m.Result = (IntPtr)1; // HTCLIENT
                    return;
                }
            }
            if (UpdateBadge != null && !UpdateBadge.IsDisposed && UpdateBadge.Visible) {
                if (UpdateBadge.ClientRectangle.Contains(UpdateBadge.PointToClient(screenPt))) {
                    m.Result = (IntPtr)1; // HTCLIENT
                    return;
                }
            }
            Point clientPt = this.PointToClient(screenPt);

            if (CloseButton != null && !CloseButton.IsDisposed && CloseButton.Visible) {
                if (CloseButton.ClientRectangle.Contains(CloseButton.PointToClient(screenPt))) {
                    m.Result = (IntPtr)20; // HTCLOSE
                    return;
                }
            }
            if (MaximizeButton != null && !MaximizeButton.IsDisposed && MaximizeButton.Visible) {
                if (MaximizeButton.ClientRectangle.Contains(MaximizeButton.PointToClient(screenPt))) {
                    m.Result = (IntPtr)9; // HTMAXBUTTON (Windows 11 Snap Layouts)
                    return;
                }
            }
            if (MinimizeButton != null && !MinimizeButton.IsDisposed && MinimizeButton.Visible) {
                if (MinimizeButton.ClientRectangle.Contains(MinimizeButton.PointToClient(screenPt))) {
                    m.Result = (IntPtr)8; // HTMINBUTTON
                    return;
                }
            }

            if (this.WindowState == FormWindowState.Normal) {
                int b = 6;
                bool left   = clientPt.X <= b;
                bool right  = clientPt.X >= this.ClientSize.Width - b;
                bool top    = clientPt.Y <= b;
                bool bottom = clientPt.Y >= this.ClientSize.Height - b;

                if (top && left)     { m.Result = (IntPtr)13; return; }
                if (top && right)    { m.Result = (IntPtr)14; return; }
                if (bottom && left)  { m.Result = (IntPtr)16; return; }
                if (bottom && right) { m.Result = (IntPtr)17; return; }
                if (left)            { m.Result = (IntPtr)10; return; }
                if (right)           { m.Result = (IntPtr)11; return; }
                if (top)             { m.Result = (IntPtr)12; return; }
                if (bottom)          { m.Result = (IntPtr)15; return; }
            }

            if (SearchPill != null && !SearchPill.IsDisposed && SearchPill.Visible) {
                if (SearchPill.ClientRectangle.Contains(SearchPill.PointToClient(screenPt))) {
                    m.Result = (IntPtr)1; // HTCLIENT
                    return;
                }
            }

            if (HeaderControl != null && !HeaderControl.IsDisposed) {
                if (HeaderControl.ClientRectangle.Contains(HeaderControl.PointToClient(screenPt))) {
                    m.Result = (IntPtr)2; // HTCAPTION (Aero Snap & Header Drag)
                    return;
                }
            }
        }

        if (m.Msg == WM_NCLBUTTONDOWN) {
            int hit = m.WParam.ToInt32();
            if (hit == 9 || hit == 8 || hit == 20) return;
        }
        if (m.Msg == WM_NCLBUTTONUP) {
            int hit = m.WParam.ToInt32();
            if (hit == 9) {
                this.WindowState = (this.WindowState == FormWindowState.Maximized) ? FormWindowState.Normal : FormWindowState.Maximized;
                m.Result = IntPtr.Zero;
                return;
            }
            if (hit == 8) {
                this.WindowState = FormWindowState.Minimized;
                m.Result = IntPtr.Zero;
                return;
            }
            if (hit == 20) {
                this.Close();
                m.Result = IntPtr.Zero;
                return;
            }
        }

        base.WndProc(ref m);
    }
}

public class Win11ToggleSwitch : Control {
    private bool _checked = false;
    private bool _isHovered = false;
    private bool _isPressed = false;
    public string OnText { get; set; }
    public string OffText { get; set; }
    public Color AccentColor { get; set; }
    public Color OffFillColor { get; set; }
    public Color OffBorderColor { get; set; }
    public Color KnobColor { get; set; }

    public event EventHandler CheckedChanged;

    public bool Checked {
        get { return _checked; }
        set {
            if (_checked != value) {
                _checked = value;
                this.Invalidate();
                if (CheckedChanged != null) CheckedChanged(this, EventArgs.Empty);
            }
        }
    }

    public void SetCheckedSilently(bool val) {
        if (_checked != val) {
            _checked = val;
            this.Invalidate();
        }
    }

    public Win11ToggleSwitch() {
        this.SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                      ControlStyles.OptimizedDoubleBuffer | ControlStyles.SupportsTransparentBackColor |
                      ControlStyles.ResizeRedraw, true);
        this.Size = new Size(110, 26);
        this.Cursor = Cursors.Hand;
        this.BackColor = Color.Transparent;
        this.OnText = "ENABLED";
        this.OffText = "DISABLED";
        this.AccentColor = Color.FromArgb(0, 120, 215);
        this.OffFillColor = Color.FromArgb(32, 36, 46);
        this.OffBorderColor = Color.FromArgb(85, 95, 115);
        this.KnobColor = Color.White;
        this.Font = new Font("Segoe UI Variable Text", 8f, FontStyle.Bold);
    }

    protected override void OnMouseEnter(EventArgs e) {
        _isHovered = true;
        this.Invalidate();
        base.OnMouseEnter(e);
    }

    protected override void OnMouseLeave(EventArgs e) {
        _isHovered = false;
        _isPressed = false;
        this.Invalidate();
        base.OnMouseLeave(e);
    }

    protected override void OnMouseDown(MouseEventArgs e) {
        if (e.Button == MouseButtons.Left) {
            _isPressed = true;
            this.Invalidate();
        }
        base.OnMouseDown(e);
    }

    protected override void OnMouseUp(MouseEventArgs e) {
        if (_isPressed && e.Button == MouseButtons.Left) {
            _isPressed = false;
            Checked = !Checked;
        }
        base.OnMouseUp(e);
    }

    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;

        int pillW = 40;
        int pillH = 20;
        int pillY = (this.Height - pillH) / 2;
        int pillX = 2;

        GraphicsPath path = new GraphicsPath();
        path.AddArc(pillX, pillY, pillH, pillH, 90, 180);
        path.AddArc(pillX + pillW - pillH, pillY, pillH, pillH, 270, 180);
        path.CloseFigure();

        if (_checked) {
            Color fill = _isHovered ? Color.FromArgb(25, 135, 230) : this.AccentColor;
            if (_isPressed) fill = Color.FromArgb(0, 105, 190);
            using (SolidBrush b = new SolidBrush(fill)) {
                g.FillPath(b, path);
            }
            int knobD = 14;
            int knobX = _isPressed ? pillX + pillW - knobD - 2 : pillX + pillW - knobD - 3;
            int knobY = pillY + (pillH - knobD) / 2;
            using (SolidBrush kb = new SolidBrush(this.KnobColor)) {
                g.FillEllipse(kb, knobX, knobY, knobD, knobD);
            }
        } else {
            Color fill = _isHovered ? Color.FromArgb(40, 46, 58) : this.OffFillColor;
            using (SolidBrush b = new SolidBrush(fill)) {
                g.FillPath(b, path);
            }
            Color border = _isHovered ? Color.FromArgb(120, 130, 155) : this.OffBorderColor;
            using (Pen p = new Pen(border, 1.2f)) {
                g.DrawPath(p, path);
            }
            int knobD = 12;
            int knobX = _isPressed ? pillX + 6 : pillX + 4;
            int knobY = pillY + (pillH - knobD) / 2;
            Color knobC = _isHovered ? Color.White : Color.FromArgb(180, 190, 205);
            using (SolidBrush kb = new SolidBrush(knobC)) {
                g.FillEllipse(kb, knobX, knobY, knobD, knobD);
            }
        }

        string text = _checked ? OnText : OffText;
        Color textC = _checked ? Color.FromArgb(240, 245, 255) : Color.FromArgb(160, 168, 182);
        using (SolidBrush tb = new SolidBrush(textC)) {
            Rectangle textRect = new Rectangle(pillX + pillW + 8, 0, this.Width - (pillX + pillW + 8), this.Height);
            StringFormat sf = new StringFormat {
                LineAlignment = StringAlignment.Center,
                Alignment = StringAlignment.Near
            };
            g.DrawString(text, this.Font, tb, textRect, sf);
        }
    }
}

public class Win11CardPanel : Panel {
    public int BorderRadius { get; set; }
    public Color NormalBackColor { get; set; }
    public Color HoverBackColor { get; set; }
    public Color BorderColor { get; set; }
    public Color HoverBorderColor { get; set; }
    public bool IsHovered { get; set; }

    public Win11CardPanel() {
        this.SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                      ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        this.BorderRadius = 8;
        this.NormalBackColor = Color.FromArgb(26, 30, 40);
        this.HoverBackColor = Color.FromArgb(34, 40, 54);
        this.BorderColor = Color.FromArgb(46, 56, 76);
        this.HoverBorderColor = Color.FromArgb(80, 130, 210);
        this.BackColor = this.NormalBackColor;
    }

    protected override void OnControlAdded(ControlEventArgs e) {
        base.OnControlAdded(e);
        if (e.Control != null && !(e.Control is Button) && !(e.Control is Win11ToggleSwitch) && !(e.Control is Win11Button)) {
            e.Control.MouseEnter += (s, ev) => { if (!IsHovered) { IsHovered = true; this.Invalidate(); } };
            e.Control.MouseLeave += (s, ev) => {
                Point p = this.PointToClient(System.Windows.Forms.Cursor.Position);
                if (!this.ClientRectangle.Contains(p)) {
                    IsHovered = false;
                    this.Invalidate();
                }
            };
        }
    }

    private GraphicsPath GetRoundPath(Rectangle r, int radius) {
        GraphicsPath path = new GraphicsPath();
        int d = radius * 2;
        path.AddArc(r.X, r.Y, d, d, 180, 90);
        path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }

    protected override void OnMouseEnter(EventArgs e) {
        IsHovered = true;
        this.Invalidate();
        base.OnMouseEnter(e);
    }

    protected override void OnMouseLeave(EventArgs e) {
        IsHovered = false;
        this.Invalidate();
        base.OnMouseLeave(e);
    }

    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;

        Rectangle rect = new Rectangle(0, 0, this.Width - 1, this.Height - 1);
        using (GraphicsPath path = GetRoundPath(rect, this.BorderRadius)) {
            Color bg = IsHovered ? HoverBackColor : NormalBackColor;
            using (SolidBrush b = new SolidBrush(bg)) {
                g.FillPath(b, path);
            }

            using (LinearGradientBrush topHighlight = new LinearGradientBrush(
                new Point(0, 0), new Point(0, 4),
                Color.FromArgb(25, 255, 255, 255), Color.Transparent)) {
                using (Pen hp = new Pen(topHighlight, 1)) {
                    g.DrawArc(hp, rect.X, rect.Y, BorderRadius * 2, BorderRadius * 2, 180, 90);
                    g.DrawLine(hp, rect.X + BorderRadius, rect.Y, rect.Right - BorderRadius, rect.Y);
                    g.DrawArc(hp, rect.Right - BorderRadius * 2, rect.Y, BorderRadius * 2, BorderRadius * 2, 270, 90);
                }
            }

            Color bc = IsHovered ? HoverBorderColor : BorderColor;
            using (Pen p = new Pen(bc, 1)) {
                g.DrawPath(p, path);
            }
        }
    }
}

public class Win11Button : Button {
    public int CornerRadius { get; set; }
    public bool IsAccent { get; set; }
    public Color AccentColor { get; set; }
    public Color NormalBackColor { get; set; }
    public Color HoverBackColor { get; set; }
    public Color PressedBackColor { get; set; }
    public Color NormalBorderColor { get; set; }
    public Color HoverBorderColor { get; set; }

    private bool _isHovered = false;
    private bool _isPressed = false;

    public Win11Button() {
        this.SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                      ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        this.FlatStyle = FlatStyle.Flat;
        this.FlatAppearance.BorderSize = 0;
        this.CornerRadius = 5;
        this.IsAccent = false;
        this.AccentColor = Color.FromArgb(0, 120, 215);
        this.NormalBackColor = Color.FromArgb(34, 42, 58);
        this.HoverBackColor = Color.FromArgb(45, 56, 78);
        this.PressedBackColor = Color.FromArgb(26, 32, 44);
        this.NormalBorderColor = Color.FromArgb(52, 64, 88);
        this.HoverBorderColor = Color.FromArgb(85, 115, 160);
        this.Cursor = Cursors.Hand;
        this.Font = new Font("Segoe UI Variable Display", 8f, FontStyle.Bold);
        this.ForeColor = Color.FromArgb(240, 245, 252);
    }

    private GraphicsPath GetRoundPath(Rectangle r, int radius) {
        GraphicsPath path = new GraphicsPath();
        int d = radius * 2;
        path.AddArc(r.X, r.Y, d, d, 180, 90);
        path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }

    protected override void OnMouseEnter(EventArgs e) {
        _isHovered = true;
        this.Invalidate();
        base.OnMouseEnter(e);
    }

    protected override void OnMouseLeave(EventArgs e) {
        _isHovered = false;
        _isPressed = false;
        this.Invalidate();
        base.OnMouseLeave(e);
    }

    protected override void OnMouseDown(MouseEventArgs e) {
        if (e.Button == MouseButtons.Left) {
            _isPressed = true;
            this.Invalidate();
        }
        base.OnMouseDown(e);
    }

    protected override void OnMouseUp(MouseEventArgs e) {
        _isPressed = false;
        this.Invalidate();
        base.OnMouseUp(e);
    }

    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;

        Rectangle rect = new Rectangle(0, 0, this.Width - 1, this.Height - 1);
        using (GraphicsPath path = GetRoundPath(rect, this.CornerRadius)) {
            Color bg;
            Color border;
            Color fg = this.ForeColor;

            if (!this.Enabled) {
                bg = Color.FromArgb(24, 28, 36);
                border = Color.FromArgb(42, 48, 62);
                fg = Color.FromArgb(105, 115, 130);
            } else if (IsAccent) {
                if (_isPressed) bg = Color.FromArgb(0, 95, 175);
                else if (_isHovered) bg = Color.FromArgb(25, 135, 235);
                else bg = this.AccentColor;
                border = Color.FromArgb(80, 165, 255);
                fg = Color.White;
            } else {
                if (_isPressed) bg = PressedBackColor;
                else if (_isHovered) bg = HoverBackColor;
                else bg = NormalBackColor;
                border = _isHovered ? HoverBorderColor : NormalBorderColor;
            }

            using (SolidBrush b = new SolidBrush(bg)) {
                g.FillPath(b, path);
            }
            using (Pen p = new Pen(border, 1)) {
                g.DrawPath(p, path);
            }

            TextRenderer.DrawText(g, this.Text, this.Font, rect, fg,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine);
        }
    }
}

public class Win11ProgressBar : Control {
    private int _val = 0;
    public Color TrackColor { get; set; }
    public Color FillColor { get; set; }
    public int Value {
        get { return _val; }
        set {
            int clamped = Math.Max(0, Math.Min(100, value));
            if (_val != clamped) {
                _val = clamped;
                this.Invalidate();
            }
        }
    }

    public Win11ProgressBar() {
        this.SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                      ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        this.TrackColor = Color.FromArgb(36, 44, 58);
        this.FillColor = Color.FromArgb(0, 120, 215);
        this.Height = 4;
    }

    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;

        int h = this.Height;
        Rectangle trackRect = new Rectangle(0, 0, this.Width, h);
        using (SolidBrush tb = new SolidBrush(TrackColor)) {
            g.FillRectangle(tb, trackRect);
        }

        if (_val > 0) {
            int fillW = Math.Max(h, (int)(this.Width * (_val / 100.0f)));
            fillW = Math.Min(this.Width, fillW);
            using (SolidBrush fb = new SolidBrush(FillColor)) {
                g.FillRectangle(fb, new Rectangle(0, 0, fillW, h));
            }
        }
    }
}
"@
}

try {
    if (-not [NativeMethods]::SetProcessDpiAwarenessContext([IntPtr](-4))) {
        try { [NativeMethods]::SetProcessDpiAwareness(2) | Out-Null } catch { [NativeMethods]::SetProcessDPIAware() | Out-Null }
    }
} catch { try { [NativeMethods]::SetProcessDPIAware() | Out-Null } catch {} }
[System.Windows.Forms.Application]::EnableVisualStyles()


function Enable-DoubleBuffering($ctrl) {
    if (-not $ctrl) { return }
    try { $ctrl.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]"Instance, NonPublic").SetValue($ctrl, $true, $null) } catch {}
}

if (-not (Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
}

$script:Theme = @{
    Bg            = [System.Drawing.Color]::FromArgb(16, 18, 24)
    Header        = [System.Drawing.Color]::FromArgb(22, 26, 36)
    Sidebar       = [System.Drawing.Color]::FromArgb(24, 28, 38)
    SidebarActive = [System.Drawing.Color]::FromArgb(35, 44, 62)
    SidebarHover  = [System.Drawing.Color]::FromArgb(29, 36, 48)
    Card          = [System.Drawing.Color]::FromArgb(26, 31, 42)
    CardHover     = [System.Drawing.Color]::FromArgb(35, 43, 58)
    CardBorder    = [System.Drawing.Color]::FromArgb(46, 56, 76)
    Accent        = [System.Drawing.Color]::FromArgb(0, 120, 215)
    AccentGlow    = [System.Drawing.Color]::FromArgb(96, 165, 250)
    Success       = [System.Drawing.Color]::FromArgb(16, 185, 129)
    Warning       = [System.Drawing.Color]::FromArgb(245, 158, 11)
    Danger        = [System.Drawing.Color]::FromArgb(239, 68, 68)
    TextMain      = [System.Drawing.Color]::FromArgb(249, 250, 251)
    TextMuted     = [System.Drawing.Color]::FromArgb(160, 168, 182)
    TextSubtle    = [System.Drawing.Color]::FromArgb(112, 122, 138)
    TerminalBg    = [System.Drawing.Color]::FromArgb(11, 13, 17)
}

$GlobalFont        = "Segoe UI Variable Display"
$GlobalFontText    = "Segoe UI Variable Text"
$IconFont          = "Segoe Fluent Icons"
$SearchPlaceholder = "Search tools, tweaks & features..."

$UI = @{
    Bullet = [char]0x2022; Dot = [char]0x25CF; Close = [char]0xE8BB; Maximize = [char]0xE922; Restore = [char]0xE923; Minimize = [char]0xE921
    Search = [char]0xE721; Bolt = [char]0xE945; Maint = [char]0xE90F; Perf = [char]0xE945; Net = [char]0xE774; Privacy = [char]0xE72E
    Context = [char]0xE8B7; Hardware = [char]0xE7F8; Apps = [char]0xEB49; Admin = [char]0xE7EF; Sparkle = [char]0xE7FC; Shield = [char]0xEA18
    Refresh = [char]0xE72C; Cpu = [char]0xE950; Ram = [char]0xE7B8; Disk = [char]0xEDA2; Uptime = [char]0xE823; Display = [char]0xE7F4
}

function Get-UserDesktopPath {
    $desk = [Environment]::GetFolderPath("Desktop")
    if (-not (Test-Path $desk)) { $desk = if ($env:USERPROFILE) { "$env:USERPROFILE\Desktop" } else { $env:TEMP } }
    return $desk
}

$ScreenBounds  = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$InitialWidth  = [math]::Max(1024, [math]::Min(2200, [int]($ScreenBounds.Width * 0.85)))
$InitialHeight = [math]::Max(680,  [math]::Min(1400, [int]($ScreenBounds.Height * 0.85)))

$Form = New-Object AdminWorksForm -Property @{
    Text = "ADMINWORKS PRO - WINDOWS 11"; Size = New-Object System.Drawing.Size($InitialWidth, $InitialHeight)
    BackColor = $script:Theme.Bg; StartPosition = "CenterScreen"; FormBorderStyle = "Sizable"
    MinimumSize = New-Object System.Drawing.Size(920, 620); KeyPreview = $true
}
$Form.SuspendLayout()
Enable-DoubleBuffering $Form

try {
    @(
        @{ Attr = 20; Val = 1 },                         # DWMWA_USE_IMMERSIVE_DARK_MODE
        @{ Attr = 33; Val = 2 },                         # DWMWA_WINDOW_CORNER_PREFERENCE = DWMWCP_ROUND
        @{ Attr = 34; Val = 0x004E382E },                # DWMWA_BORDER_COLOR
        @{ Attr = (if ($script:OSBuild -ge 22621) { 38 } else { 1029 }); Val = (if ($script:OSBuild -ge 22621) { 2 } else { 1 }) } # DWMWA_SYSTEMBACKDROP_TYPE = Mica
    ) | ForEach-Object {
        $val = [int]$_.Val
        [NativeMethods]::DwmSetWindowAttribute($Form.Handle, $_.Attr, [ref]$val, 4) | Out-Null
    }
    $margins = New-Object NativeMethods+MARGINS -Property @{ cxLeftWidth = -1; cxRightWidth = -1; cyTopHeight = -1; cyBottomHeight = -1 }
    [NativeMethods]::DwmExtendFrameIntoClientArea($Form.Handle, [ref]$margins) | Out-Null
    
} catch {}

$Header = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Top"; Height = 64; BackColor = $script:Theme.Header }
$Form.Controls.Add($Header)
$Form.HeaderControl = $Header

$BrandPanel = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Left"; Width = 265; BackColor = $script:Theme.Header }
$LogoIcon = New-Object System.Windows.Forms.Label -Property @{
    Text = $UI.Bolt; Location = New-Object System.Drawing.Point(14, 14); Size = New-Object System.Drawing.Size(26, 26)
    ForeColor = $script:Theme.AccentGlow; Font = New-Object System.Drawing.Font($GlobalFont, 14, [System.Drawing.FontStyle]::Bold); UseMnemonic = $false
}
$TitleLbl = New-Object System.Windows.Forms.Label -Property @{
    Text = "ADMINWORKS"; Location = New-Object System.Drawing.Point(44, 12); AutoSize = $true
    ForeColor = $script:Theme.TextMain; Font = New-Object System.Drawing.Font($GlobalFont, 12, [System.Drawing.FontStyle]::Bold); UseMnemonic = $false
}
$BadgePro = New-Object System.Windows.Forms.Label -Property @{
    Text = "v6.1"; Location = New-Object System.Drawing.Point(168, 14); Size = New-Object System.Drawing.Size(42, 17)
    BackColor = [System.Drawing.Color]::FromArgb(26, 34, 48); ForeColor = $script:Theme.AccentGlow
    Font = New-Object System.Drawing.Font($GlobalFont, 7, [System.Drawing.FontStyle]::Bold); TextAlign = "MiddleCenter"; UseMnemonic = $false
}
$BadgePro.Add_Paint({ param($s,$e) $pen = New-Object System.Drawing.Pen($script:Theme.CardBorder, 1); $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width-1, $s.Height-1); $pen.Dispose() })

$TitleSub = New-Object System.Windows.Forms.Label -Property @{
    Text = "Windows 11  $($UI.Bullet)  Kushagra Karira"; Location = New-Object System.Drawing.Point(44, 35); Size = New-Object System.Drawing.Size(215, 18)
    ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($GlobalFontText, 7.5, [System.Drawing.FontStyle]::Bold)
    Cursor = [System.Windows.Forms.Cursors]::Hand; UseMnemonic = $false; AutoSize = $false; TextAlign = "MiddleLeft"
}
$TitleSub.Add_Click({ Start-Process "https://github.com/KushagraKarira/AdminWorks/releases" })
$TitleSub.Add_MouseEnter({ $this.ForeColor = $script:Theme.AccentGlow })
$TitleSub.Add_MouseLeave({ $this.ForeColor = $script:Theme.TextMuted })

$UpTip = New-Object System.Windows.Forms.ToolTip
$UpdateBadge = New-Object System.Windows.Forms.Label -Property @{
    Text = "UPDATE"; Location = New-Object System.Drawing.Point(168, 14); Size = New-Object System.Drawing.Size(68, 17)
    BackColor = [System.Drawing.Color]::FromArgb(16, 45, 32); ForeColor = $script:Theme.Success
    Font = New-Object System.Drawing.Font($GlobalFont, 7, [System.Drawing.FontStyle]::Bold); TextAlign = "MiddleCenter"
    Cursor = [System.Windows.Forms.Cursors]::Hand; Visible = $false; UseMnemonic = $false
}
$UpdateBadge.Add_Paint({ param($s,$e) $pen = New-Object System.Drawing.Pen($script:Theme.Success, 1); $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width-1, $s.Height-1); $pen.Dispose() })
$UpdateBadge.Add_MouseEnter({ $this.BackColor = $script:Theme.Success; $this.ForeColor = [System.Drawing.Color]::White })
$UpdateBadge.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::FromArgb(16, 45, 32); $this.ForeColor = $script:Theme.Success })
$UpdateBadge.Add_Click({ Update-AdminWorksSuite $this })

$BrandPanel.Controls.AddRange(@($LogoIcon, $TitleLbl, $BadgePro, $TitleSub, $UpdateBadge))

$RightHeader = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Right"; Width = 440; BackColor = $script:Theme.Header }
$CtrlBox     = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Right"; Width = 135; BackColor = $script:Theme.Header }
$RightHeader.Controls.Add($CtrlBox)

function New-WindowBtn($Glyph, $X, $HoverColor, $Action) {
    $B = New-Object System.Windows.Forms.Button -Property @{
        Text = $Glyph; Size = New-Object System.Drawing.Size(42, 32); Location = New-Object System.Drawing.Point($X, 16)
        FlatStyle = "Flat"; ForeColor = $script:Theme.TextMuted; Tag = $HoverColor; Font = New-Object System.Drawing.Font($IconFont, 9); UseMnemonic = $false
    }
    $B.FlatAppearance.BorderSize = 0
    $B.Add_Click($Action)
    $B.Add_MouseEnter({ $this.BackColor = $this.Tag; $this.ForeColor = [System.Drawing.Color]::White })
    $B.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::Transparent; $this.ForeColor = $script:Theme.TextMuted })
    $CtrlBox.Controls.Add($B)
    return $B
}

$BtnClose = New-WindowBtn $UI.Close 88 $script:Theme.Danger { $Form.Close() }
$BtnMax   = New-WindowBtn $UI.Maximize 44 $script:Theme.CardHover { $Form.WindowState = if ($Form.WindowState -eq "Maximized") { "Normal" } else { "Maximized" } }
$BtnMin   = New-WindowBtn $UI.Minimize 2 $script:Theme.CardHover { $Form.WindowState = "Minimized" }

$Form.MaximizeButton   = $BtnMax
$Form.MinimizeButton   = $BtnMin
$Form.CloseButton      = $BtnClose
$Form.TitleSub         = $TitleSub
$Form.UpdateBadge      = $UpdateBadge
$Form.CloseHoverColor  = $script:Theme.Danger
$Form.ButtonHoverColor = $script:Theme.CardHover
$Form.TextMutedColor   = $script:Theme.TextMuted

$Form.Add_ClientSizeChanged({ $BtnMax.Text = if ($Form.WindowState -eq "Maximized") { $UI.Restore } else { $UI.Maximize } })

$SearchWrapper = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Fill"; Padding = New-Object System.Windows.Forms.Padding(6, 16, 12, 16); BackColor = $script:Theme.Header }
$RightHeader.Controls.Add($SearchWrapper)

$SearchPill = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Fill"; BackColor = $script:Theme.Sidebar }
$SearchPill.Add_Paint({
    param($s, $e)
    $isFocused = ($SearchBox.Focused -or ($SearchBox.Text -ne $SearchPlaceholder -and $SearchBox.Text.Trim() -ne ""))
    $borderColor = if ($isFocused) { $script:Theme.AccentGlow } else { $script:Theme.CardBorder }
    $pen = New-Object System.Drawing.Pen($borderColor, 1)
    $e.Graphics.DrawRectangle($pen, 0, 0, ($s.Width - 1), ($s.Height - 1))
    $pen.Dispose()
    if ($isFocused) {
        $accentPen = New-Object System.Drawing.Pen($script:Theme.Accent, 2)
        $e.Graphics.DrawLine($accentPen, 1, ($s.Height - 1), ($s.Width - 2), ($s.Height - 1))
        $accentPen.Dispose()
    }
})
$SearchWrapper.Controls.Add($SearchPill)
$Form.SearchPill = $SearchPill

$SearchIconLbl = New-Object System.Windows.Forms.Label -Property @{
    Text = $UI.Search; Location = New-Object System.Drawing.Point(8, 7); Size = New-Object System.Drawing.Size(20, 20)
    ForeColor = $script:Theme.TextSubtle; Font = New-Object System.Drawing.Font($IconFont, 9); UseMnemonic = $false
}
$SearchBox = New-Object System.Windows.Forms.TextBox -Property @{
    BorderStyle = "None"; BackColor = $script:Theme.Sidebar; ForeColor = $script:Theme.TextSubtle
    Font = New-Object System.Drawing.Font($GlobalFont, 9); Location = New-Object System.Drawing.Point(30, 8); Width = 250; Text = $SearchPlaceholder
    Anchor = [System.Windows.Forms.AnchorStyles]"Top, Left, Right"
}
$SearchBox.Add_GotFocus({ if ($this.Text -eq $SearchPlaceholder) { $this.Text = ""; $this.ForeColor = $script:Theme.TextMain }; $SearchPill.Invalidate() })
$SearchBox.Add_LostFocus({ if ([string]::IsNullOrWhiteSpace($this.Text)) { $this.Text = $SearchPlaceholder; $this.ForeColor = $script:Theme.TextSubtle }; $SearchPill.Invalidate() })
$SearchBox.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $this.Text = $SearchPlaceholder; $this.ForeColor = $script:Theme.TextSubtle; [void]$Form.Focus(); $_.SuppressKeyPress = $true }
})

$SearchCountLbl = New-Object System.Windows.Forms.Label -Property @{
    Text = ""; Location = New-Object System.Drawing.Point(206, 7); Size = New-Object System.Drawing.Size(70, 16); ForeColor = $script:Theme.AccentGlow
    Font = New-Object System.Drawing.Font($GlobalFont, 7, [System.Drawing.FontStyle]::Bold); BackColor = $script:Theme.Sidebar; TextAlign = "MiddleRight"
    Anchor = [System.Windows.Forms.AnchorStyles]"Top, Right"; Visible = $false; UseMnemonic = $false
}
$SearchPill.Controls.AddRange(@($SearchIconLbl, $SearchBox, $SearchCountLbl))

$CenterPanel = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Fill"; BackColor = $script:Theme.Header; Padding = New-Object System.Windows.Forms.Padding(12, 0, 12, 0) }
$OSCaption = try { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).ProductName } catch { "Windows 11" }
if (-not $OSCaption -or $OSCaption -like "*Windows 10*") { $OSCaption = "Windows 11 (Build $script:OSBuild)" }
$LocalIP = "LAN"
try {
    $dnsIP = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) | Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and -not [System.Net.IPAddress]::IsLoopback($_) } | Select-Object -First 1
    if ($dnsIP) { $LocalIP = $dnsIP.IPAddressToString }
} catch {}

$SysBadge = New-Object System.Windows.Forms.Label -Property @{
    Text = "$($env:COMPUTERNAME)  $($UI.Bullet)  IP: $LocalIP  $($UI.Bullet)  $OSCaption"; Dock = "Fill"; TextAlign = "MiddleCenter"
    ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($GlobalFont, 8.5); AutoEllipsis = $true; UseMnemonic = $false
}
$CenterPanel.Controls.Add($SysBadge)
$Header.Controls.AddRange(@($CenterPanel, $BrandPanel, $RightHeader))
$BrandPanel.SendToBack(); $RightHeader.SendToBack(); $CenterPanel.BringToFront()

$Header.Add_Paint({ param($s, $e) $pen = New-Object System.Drawing.Pen($script:Theme.CardBorder, 1); $e.Graphics.DrawLine($pen, 0, ($s.Height - 1), $s.Width, ($s.Height - 1)); $pen.Dispose() })

$LogContainer = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Bottom"; Height = 34; BackColor = $script:Theme.TerminalBg; Padding = New-Object System.Windows.Forms.Padding(14, 4, 14, 8) }
$Form.Controls.Add($LogContainer)

$TermHeader = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Top"; Height = 30; BackColor = $script:Theme.TerminalBg }
$LogContainer.Controls.Add($TermHeader)

$TermTitle = New-Object System.Windows.Forms.Label -Property @{
    Text = "$($UI.Dot) CONSOLE OUTPUT & EXECUTION LOG"; Location = New-Object System.Drawing.Point(0, 5); AutoSize = $true
    ForeColor = $script:Theme.Success; Font = New-Object System.Drawing.Font($GlobalFont, 8, [System.Drawing.FontStyle]::Bold); UseMnemonic = $false
}
$TermHeader.Controls.Add($TermTitle)

$TermBtnContainer = New-Object System.Windows.Forms.FlowLayoutPanel -Property @{ Dock = "Right"; Width = 390; Height = 28; FlowDirection = "RightToLeft"; BackColor = $script:Theme.TerminalBg }
$TermHeader.Controls.Add($TermBtnContainer)

$LogBox = New-Object System.Windows.Forms.RichTextBox -Property @{
    Dock = "Fill"; BackColor = [System.Drawing.Color]::FromArgb(6, 8, 11); ForeColor = $script:Theme.TextMain; BorderStyle = "None"; ReadOnly = $true
    Font = New-Object System.Drawing.Font("Cascadia Mono", 9, [System.Drawing.FontStyle]::Regular)
}
if (-not (New-Object System.Drawing.Font("Cascadia Mono", 9)).FontFamily.Name.Equals("Cascadia Mono", [StringComparison]::OrdinalIgnoreCase)) {
    $LogBox.Font = New-Object System.Drawing.Font("Consolas", 9)
}
$LogContainer.Controls.Add($LogBox); $LogBox.BringToFront()
$TermHeader.Add_Paint({ param($s, $e) $pen = New-Object System.Drawing.Pen($script:Theme.CardBorder, 1); $e.Graphics.DrawLine($pen, 0, 0, $s.Width, 0); $pen.Dispose() })

function New-TermBtn($Text, $Action) {
    $Btn = New-Object Win11Button -Property @{
        Text = $Text; Size = New-Object System.Drawing.Size(80, 24); Margin = New-Object System.Windows.Forms.Padding(3, 1, 3, 1)
        CornerRadius = 4; NormalBackColor = $script:Theme.Card; HoverBackColor = $script:Theme.CardHover
        NormalBorderColor = $script:Theme.CardBorder; HoverBorderColor = $script:Theme.AccentGlow
    }
    $Btn.Font = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold)
    $Btn.Add_Click($Action)
    $TermBtnContainer.Controls.Add($Btn)
}

$BtnToggleDrawer = New-Object Win11Button -Property @{
    Text = "EXPAND"; Size = New-Object System.Drawing.Size(88, 24); Margin = New-Object System.Windows.Forms.Padding(3, 1, 3, 1)
    CornerRadius = 4; NormalBackColor = $script:Theme.Card; HoverBackColor = $script:Theme.CardHover
    NormalBorderColor = $script:Theme.CardBorder; HoverBorderColor = $script:Theme.AccentGlow
    ForeColor = $script:Theme.AccentGlow
}
$BtnToggleDrawer.Font = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold)
$BtnToggleDrawer.Add_Click({
    if ($LogContainer.Height -gt 40) { $LogContainer.Height = 34; $BtnToggleDrawer.Text = "EXPAND" } else { $LogContainer.Height = 180; $BtnToggleDrawer.Text = "COLLAPSE" }
})
$TermBtnContainer.Controls.Add($BtnToggleDrawer)

New-TermBtn "EXPORT" { 
    $Path = Join-Path (Get-UserDesktopPath) "AdminWorks_Log_$((Get-Date).ToString('yyyy-MM-dd_HHmmss')).txt"
    ($LogBox.Text) | Out-File -FilePath $Path -Encoding UTF8
    Write-Log "Log exported to: $Path" "Success"
}
New-TermBtn "COPY ALL" { 
    if ($LogBox.Text.Trim()) { [System.Windows.Forms.Clipboard]::SetText($LogBox.Text); Write-Log "Console copied." "Success" }
}
New-TermBtn "CLEAR" { $LogBox.Clear(); Write-Log "Console cleared." "Info" }

function Write-Log ($Msg, $Type = "Info") {
    if ([string]::IsNullOrWhiteSpace($Msg) -or -not $LogBox -or $LogBox.IsDisposed) { return }
    try {
        [void]$LogBox.Invoke([System.Action[string, string]]{
            param($m, $t)
            if (-not $LogBox -or $LogBox.IsDisposed) { return }
            $LogBox.SelectionStart = $LogBox.TextLength
            $LogBox.SelectionColor = switch ($t) {
                "Success" { $script:Theme.Success } "Warning" { $script:Theme.Warning } "Error" { $script:Theme.Danger } "Exec" { $script:Theme.AccentGlow } Default { $script:Theme.TextMuted }
            }
            $LogBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [$($t.ToUpper().PadRight(7))] $m`n")
            $LogBox.ScrollToCaret()
        }, $Msg, $Type)
    } catch {}
}

$BodyPanel = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Fill"; BackColor = $script:Theme.Bg }
$Form.Controls.Add($BodyPanel)
$Header.SendToBack(); $LogContainer.SendToBack(); $BodyPanel.BringToFront()

$Sidebar = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Left"; Width = 265; BackColor = $script:Theme.Sidebar; AutoScroll = $true }
$Sidebar.HorizontalScroll.Enabled = $false; $Sidebar.HorizontalScroll.Visible = $false
$BodyPanel.Controls.Add($Sidebar)
$Sidebar.Add_Paint({ param($s, $e) $pen = New-Object System.Drawing.Pen($script:Theme.CardBorder, 1); $e.Graphics.DrawLine($pen, ($s.Width - 1), 0, ($s.Width - 1), $s.Height); $pen.Dispose() })

$ContentArea = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Fill"; BackColor = $script:Theme.Bg }
$BodyPanel.Controls.Add($ContentArea)
$Sidebar.SendToBack(); $ContentArea.BringToFront()

$TelemetryBar = New-Object System.Windows.Forms.TableLayoutPanel -Property @{
    Dock = "Top"; Height = 66; BackColor = $script:Theme.SidebarActive; ColumnCount = 4; RowCount = 1; Padding = New-Object System.Windows.Forms.Padding(16, 6, 16, 6)
}
1..4 | ForEach-Object { [void]$TelemetryBar.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25))) }
$ContentArea.Controls.Add($TelemetryBar)
$TelemetryBar.Add_Paint({ param($s, $e) $pen = New-Object System.Drawing.Pen($script:Theme.CardBorder, 1); $e.Graphics.DrawLine($pen, 0, ($s.Height - 1), $s.Width, ($s.Height - 1)); $pen.Dispose() })

function New-StatWidget($IconGlyph, $Title) {
    $P = New-Object Win11CardPanel -Property @{
        Dock = "Fill"; BorderRadius = 6; Margin = New-Object System.Windows.Forms.Padding(6, 4, 6, 4)
        NormalBackColor = $script:Theme.Card; HoverBackColor = $script:Theme.CardHover
        BorderColor = $script:Theme.CardBorder; HoverBorderColor = $script:Theme.AccentGlow
    }
    $LIcon = New-Object System.Windows.Forms.Label -Property @{ Text = $IconGlyph; Location = New-Object System.Drawing.Point(10, 8); Size = New-Object System.Drawing.Size(18, 16); ForeColor = $script:Theme.AccentGlow; Font = New-Object System.Drawing.Font($IconFont, 8.5); UseMnemonic = $false }
    $LTitle = New-Object System.Windows.Forms.Label -Property @{ Text = $Title; Location = New-Object System.Drawing.Point(32, 8); AutoSize = $true; ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($GlobalFont, 7, [System.Drawing.FontStyle]::Bold); UseMnemonic = $false }
    $LVal = New-Object System.Windows.Forms.Label -Property @{ Text = "--"; Location = New-Object System.Drawing.Point(32, 24); AutoSize = $true; ForeColor = $script:Theme.TextMain; Font = New-Object System.Drawing.Font($GlobalFont, 9, [System.Drawing.FontStyle]::Bold); UseMnemonic = $false }
    
    $Meter = New-Object Win11ProgressBar -Property @{ Dock = "Bottom"; Height = 4; TrackColor = [System.Drawing.Color]::FromArgb(35, 44, 62); FillColor = $script:Theme.Accent }
    $LVal | Add-Member -MemberType NoteProperty -Name "Meter" -Value $Meter -Force
    $P.Controls.AddRange(@($LIcon, $LTitle, $LVal, $Meter))
    $TelemetryBar.Controls.Add($P)
    return $LVal
}

$StatCPU  = New-StatWidget $UI.Cpu "CPU LOAD"
$StatRAM  = New-StatWidget $UI.Ram "MEMORY USED"
$StatDisk = New-StatWidget $UI.Disk "SYSTEM DRIVE (C:)"
$StatUp   = New-StatWidget $UI.Uptime "SYSTEM UPTIME"

$script:CpuCounter = try { $c = New-Object System.Diagnostics.PerformanceCounter("Processor", "% Processor Time", "_Total"); $null = $c.NextValue(); $c } catch { $null }

$script:AllCards       = New-Object System.Collections.Generic.List[PSObject]
$script:ToggleCards    = New-Object System.Collections.Generic.List[PSObject]
$script:CategoryPanels = @{}
$script:SidebarItems   = @{}
$script:CurrentTabId   = "Maint"

$ViewContainer = New-Object System.Windows.Forms.Panel -Property @{ Dock = "Fill"; BackColor = $script:Theme.Bg }
$ContentArea.Controls.Add($ViewContainer)
$TelemetryBar.SendToBack(); $ViewContainer.BringToFront()
Enable-DoubleBuffering $ViewContainer

function Update-ResponsiveLayout {
    if (-not $ViewContainer -or $ViewContainer.ClientSize.Width -le 100) { return }
    $sbWidth = [math]::Max(18, [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth)
    $availWidth = [math]::Max(280, ($ViewContainer.ClientSize.Width - 32 - $sbWidth))
    $cols = [math]::Min(16, [math]::Max(1, [math]::Floor($availWidth / 330)))
    $targetWidth = [math]::Floor($availWidth / $cols) - 12
    if ($targetWidth -lt 280 -and $cols -gt 1) {
        $cols = [int]($cols - 1)
        $targetWidth = [math]::Floor($availWidth / $cols) - 12
    }
    $targetWidth = [math]::Max(280, $targetWidth)
    $activePanel = $script:CategoryPanels[$script:CurrentTabId]
    if ($activePanel) { 
        $activePanel.SuspendLayout() 
        $activePanel.HorizontalScroll.Enabled = $false; $activePanel.HorizontalScroll.Visible = $false; $activePanel.HorizontalScroll.Maximum = 0
        foreach ($ctrl in $activePanel.Controls) {
            if ($ctrl -is [System.Windows.Forms.Panel] -or $ctrl -is [Win11CardPanel]) {
                if ($ctrl.Tag -eq "Banner") { $ctrl.Width = $availWidth; $ctrl.Height = 34 }
                else { $ctrl.Width = $targetWidth }
            }
        }
        $activePanel.ResumeLayout($true)
        try {
            
            [void][NativeMethods]::SetWindowTheme($activePanel.Handle, "DarkMode_Explorer", $null)
            [void][NativeMethods]::ShowScrollBar($activePanel.Handle, 0, $false)
        } catch {}
    }
}
$ViewContainer.Add_SizeChanged({ Update-ResponsiveLayout })

$script:IsExecuting = $false
$script:CurrentRunningTask = "Ready"

function Invoke-AdminWorksAction ($ActionCode, $Button = $null, [scriptblock]$OnComplete = $null) {
    if ($script:IsExecuting) {
        [System.Windows.Forms.MessageBox]::Show(
            "Another servicing or optimization task is currently running ($script:CurrentRunningTask).`nPlease wait for it to complete.",
            "Operation in Progress",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }
    $taskTitle = if ($Button -and $Button.Parent -and $Button.Parent.Controls[2]) { $Button.Parent.Controls[2].Text } else { "System Task" }
    $script:IsExecuting = $true
    $script:CurrentRunningTask = $taskTitle

    if ($Button -and -not $Button.IsDisposed) {
        $Button.Enabled = $false
        if ($Button -is [Win11Button]) {
            $Button.Text = "RUNNING..."
            $Button.NormalBackColor = $script:Theme.Warning
            $Button.ForeColor = [System.Drawing.Color]::Black
        }
    }
    if ($LogContainer.Height -le 40) { $LogContainer.Height = 180; $BtnToggleDrawer.Text = "COLLAPSE" }

    $PS = [powershell]::Create().AddScript({
        param($CodeStr, $LogBox, $Theme)
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue
        if (-not (Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)) {
            New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
        }
        function Write-Log ($Msg, $Type = "Info") {
            if ([string]::IsNullOrWhiteSpace($Msg) -or -not $LogBox -or $LogBox.IsDisposed) { return }
            try {
                [void]$LogBox.Invoke([System.Action[string, string]]{
                    param($m, $t)
                    if (-not $LogBox -or $LogBox.IsDisposed) { return }
                    $LogBox.SelectionStart = $LogBox.TextLength
                    $LogBox.SelectionColor = switch ($t) { "Success" { $Theme.Success } "Warning" { $Theme.Warning } "Error" { $Theme.Danger } "Exec" { $Theme.AccentGlow } Default { $Theme.TextMuted } }
                    $LogBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] [$($t.ToUpper().PadRight(7))] $m`n")
                    $LogBox.ScrollToCaret()
                }, $Msg, $Type)
            } catch {}
        }
        function Restart-Explorer {
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 600
            if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
        }
        function Get-UserDesktopPath {
            $desk = [Environment]::GetFolderPath("Desktop")
            if (-not (Test-Path $desk)) { $desk = if ($env:USERPROFILE) { "$env:USERPROFILE\Desktop" } else { $env:TEMP } }
            return $desk
        }
        function Update-AdminWorksSuite {
            Write-Log "Navigating to AdminWorks GitHub Releases..." "Exec"
            Start-Process "https://github.com/KushagraKarira/AdminWorks/releases"
            Write-Log "GitHub Releases opened in browser." "Success"
        }
        function Set-PowerSchemeUltimate {
            $planOut = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
            if ($planOut -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})') { powercfg /setactive $matches[1] | Out-Null }
            else { powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Out-Null }
        }
        function Install-WingetPackage ($PackageId, $Name, $Source = $null) {
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "Winget is missing. Run 'Install / Repair Winget' first." "Error"; return }
            Write-Log "Installing $Name via Winget..." "Exec"
            $cmdArgs = @("install", $PackageId, "--silent", "--accept-package-agreements", "--accept-source-agreements", "--disable-interactivity")
            if ($Source) { $cmdArgs += @("--source", $Source) }
            winget @cmdArgs | Out-Null
            Write-Log "$Name installation completed." "Success"
        }
        try {
            $Exec = [scriptblock]::Create($CodeStr)
            & $Exec
        } catch { Write-Log "Execution Error: $($_.Exception.Message)" "Error" }
    }).AddArgument($ActionCode).AddArgument($LogBox).AddArgument($script:Theme)

    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.ThreadOptions = "ReuseThread"
    $Runspace.Open()
    $PS.Runspace = $Runspace
    $null = $PS.BeginInvoke()

    $Timer = New-Object System.Windows.Forms.Timer -Property @{Interval = 300}
    $Timer.Tag = @{ Button = $Button; PS = $PS; Runspace = $Runspace; OnComplete = $OnComplete }
    $Timer.Add_Tick({
        $State = $this.Tag
        if ($State.PS.InvocationStateInfo.State -ne "Running") {
            $script:IsExecuting = $false
            $script:CurrentRunningTask = "Ready"
            if ($State.Button -and -not $State.Button.IsDisposed) {
                $State.Button.Enabled = $true
                if ($State.OnComplete) { & $State.OnComplete $State.Button }
                else {
                    if ($State.Button -is [Win11Button]) {
                        $State.Button.Text = "DONE"
                        $State.Button.NormalBackColor = $script:Theme.Success
                        $State.Button.ForeColor = [System.Drawing.Color]::White
                    }
                }
            }
            try { $State.PS.Dispose() } catch {}
            try { $State.Runspace.Close(); $State.Runspace.Dispose() } catch {}
            $this.Stop(); $this.Dispose()
        }
    })
    $Timer.Start()
}

function New-BaseCardPanel ($CategoryPanel, $CategoryTag, $IconGlyph, $Title, $Desc, $IsToggle) {
    $P = New-Object Win11CardPanel -Property @{
        Size = New-Object System.Drawing.Size(320, 162); Margin = New-Object System.Windows.Forms.Padding(6)
        BorderRadius = 8; NormalBackColor = $script:Theme.Card; HoverBackColor = $script:Theme.CardHover
        BorderColor = $script:Theme.CardBorder; HoverBorderColor = $script:Theme.AccentGlow
    }

    $TagLbl = New-Object System.Windows.Forms.Label -Property @{
        Text = if ($IsToggle) { "$($CategoryTag.ToUpper())  $($UI.Bullet)  TOGGLE" } else { $CategoryTag.ToUpper() }
        Location = New-Object System.Drawing.Point(14, 10); AutoSize = $true; ForeColor = $script:Theme.AccentGlow
        Font = New-Object System.Drawing.Font($GlobalFont, 7, [System.Drawing.FontStyle]::Bold); UseMnemonic = $false
    }

    $IconBox = New-Object System.Windows.Forms.Panel -Property @{
        Location = New-Object System.Drawing.Point(14, 26); Size = New-Object System.Drawing.Size(22, 22)
        BackColor = [System.Drawing.Color]::FromArgb(20, 96, 165, 250)
    }
    $IconBox.Add_Paint({ param($s,$e) $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(40, 96, 165, 250), 1); $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width-1, $s.Height-1); $pen.Dispose() })

    $IconLbl = New-Object System.Windows.Forms.Label -Property @{
        Text = $IconGlyph; Dock = "Fill"; TextAlign = "MiddleCenter"
        ForeColor = $script:Theme.AccentGlow; Font = New-Object System.Drawing.Font($IconFont, 9.5); UseMnemonic = $false
    }
    $IconBox.Controls.Add($IconLbl)

    $TitleLbl = New-Object System.Windows.Forms.Label -Property @{
        Text = $Title; Location = New-Object System.Drawing.Point(42, 28); Size = New-Object System.Drawing.Size(264, 20)
        Anchor = [System.Windows.Forms.AnchorStyles]"Top, Left, Right"; ForeColor = $script:Theme.TextMain
        Font = New-Object System.Drawing.Font($GlobalFont, 9, [System.Drawing.FontStyle]::Bold); AutoEllipsis = $true; UseMnemonic = $false
    }
    $DescLbl = New-Object System.Windows.Forms.Label -Property @{
        Text = $Desc; Location = New-Object System.Drawing.Point(14, 54); Size = New-Object System.Drawing.Size(292, 56)
        Anchor = [System.Windows.Forms.AnchorStyles]"Top, Left, Right"; ForeColor = $script:Theme.TextMuted
        Font = New-Object System.Drawing.Font($GlobalFontText, 8); AutoEllipsis = $true; UseMnemonic = $false
    }

    $P.Controls.AddRange(@($TagLbl, $IconBox, $TitleLbl, $DescLbl))
    return $P
}

function New-TweakCard ($CategoryPanel, $IconGlyph, $Title, $CategoryTag, $Desc, $Action) {
    $P = New-BaseCardPanel $CategoryPanel $CategoryTag $IconGlyph $Title $Desc $false

    $Btn = New-Object Win11Button -Property @{
        Text = "APPLY"; Size = New-Object System.Drawing.Size(88, 28); Location = New-Object System.Drawing.Point(218, 114)
        Anchor = [System.Windows.Forms.AnchorStyles]"Bottom, Right"; CornerRadius = 5
        IsAccent = $false; NormalBackColor = $script:Theme.SidebarActive; HoverBackColor = $script:Theme.Accent
        NormalBorderColor = $script:Theme.CardBorder; HoverBorderColor = $script:Theme.AccentGlow
        Tag = $Action.ToString()
    }
    $Btn.Font = New-Object System.Drawing.Font($GlobalFont, 7.5, [System.Drawing.FontStyle]::Bold)
    $Btn.Add_Click({
        Invoke-AdminWorksAction $this.Tag $this {
            param($b)
            if ($b -is [Win11Button]) {
                $b.Text = "DONE"
                $b.NormalBackColor = $script:Theme.Success
                $b.ForeColor = [System.Drawing.Color]::White
            }
        }
    })
    $P.Controls.Add($Btn); $CategoryPanel.Controls.Add($P)
    $script:AllCards.Add([PSCustomObject]@{ Title = $Title; Category = $CategoryTag; Description = $Desc; Panel = $P })
}

function Update-ToggleStateVisual ($ToggleSwitch, $Active) {
    if (-not $ToggleSwitch) { return }
    $ToggleSwitch.SetCheckedSilently($Active)
}

function New-ToggleCard ($CategoryPanel, $IconGlyph, $Title, $CategoryTag, $Desc, $CheckAction, $EnableAction, $DisableAction) {
    $P = New-BaseCardPanel $CategoryPanel $CategoryTag $IconGlyph $Title $Desc $true

    $Toggle = New-Object Win11ToggleSwitch -Property @{
        Location = New-Object System.Drawing.Point(198, 114); Size = New-Object System.Drawing.Size(110, 26)
        Anchor = [System.Windows.Forms.AnchorStyles]"Bottom, Right"
        AccentColor = $script:Theme.Accent; OffFillColor = $script:Theme.SidebarActive
        OffBorderColor = $script:Theme.CardBorder
    }
    
    $ToggleMeta = [PSCustomObject]@{
        Control = $Toggle
        CheckAction = $CheckAction
        EnableCode = $EnableAction.ToString()
        DisableCode = $DisableAction.ToString()
        IsActive = $false
    }
    $Toggle.Tag = $ToggleMeta

    $Toggle.Add_CheckedChanged({
        $T = $this; $Meta = $T.Tag; $TargetActive = $T.Checked
        $TargetCode = if ($TargetActive) { $Meta.EnableCode } else { $Meta.DisableCode }
        $Meta.IsActive = $TargetActive
        Invoke-AdminWorksAction $TargetCode $T { param($ctrl) }
    })

    $P.Controls.Add($Toggle); $CategoryPanel.Controls.Add($P)
    $script:AllCards.Add([PSCustomObject]@{ Title = $Title; Category = $CategoryTag; Description = $Desc; Panel = $P })
    $script:ToggleCards.Add($ToggleMeta)
}

function New-RegToggle ($Panel, $Icon, $Title, $Tag, $Desc, $Path, $Name, $OnVal = 1, $OffVal = 0, $RestartExp = $false) {
    $p = "$Path" -replace '^HKCU:\\?', 'HKCU\' -replace '^HKLM:\\?', 'HKLM\'
    $restartCode = if ($RestartExp) { "Restart-Explorer;" } else { "" }
    $enableCode = "reg add `"$p`" /v `"$Name`" /t REG_DWORD /d $OnVal /f | Out-Null; $restartCode Write-Log `"$Title enabled.`" `"Success`""
    $disableCode = "reg add `"$p`" /v `"$Name`" /t REG_DWORD /d $OffVal /f | Out-Null; $restartCode Write-Log `"$Title disabled.`" `"Warning`""
    $checkAction = { (Get-ItemProperty $Path -ErrorAction SilentlyContinue).$Name -eq $OnVal }.GetNewClosure()

    New-ToggleCard $Panel $Icon $Title $Tag $Desc $checkAction $enableCode $disableCode
}

function Update-AdminWorksSuite ($TriggerButton = $null) {
    Write-Log "Navigating to AdminWorks GitHub Releases..." "Exec"
    Start-Process "https://github.com/KushagraKarira/AdminWorks/releases"
    Write-Log "GitHub Releases opened in browser." "Success"
    if ($TriggerButton -and -not $TriggerButton.IsDisposed) {
        $TriggerButton.Text = "OPENED"
        if ($TriggerButton -is [Win11Button]) { $TriggerButton.NormalBackColor = $script:Theme.Success }
        else { $TriggerButton.BackColor = $script:Theme.Success }
    }
}

$TabList = @(
    @{ Id = "Maint";     Icon = $UI.Maint;    Name = "Maintenance";     Desc = "DISM, SFC, WinSxS reduction, Component Repair & Event Log Cleaning" },
    @{ Id = "Perf";      Icon = $UI.Perf;     Name = "Performance";     Desc = "Power plans, Thread priority separation, RAM & Latency Tuning" },
    @{ Id = "Net";       Icon = $UI.Net;      Name = "Network & DNS";   Desc = "DNS benchmarks, Wi-Fi keys, TCP/IP stack, RDP & Port Listeners" },
    @{ Id = "Privacy";   Icon = $UI.Privacy;  Name = "Privacy & Bloat"; Desc = "Telemetry removal, Bing search, Recall AI & Lock Screen Ads" },
    @{ Id = "Context";   Icon = $UI.Context;  Name = "Shell & Explorer";Desc = "Classic Context Menus, File extensions, Compact Mode & Pro Tools" },
    @{ Id = "Hardware";  Icon = $UI.Hardware; Name = "Hardware Audit";  Desc = "SMART Disk health, BIOS/UEFI, RAM Module speeds & GPU Specs" },
    @{ Id = "Apps";      Icon = $UI.Apps;     Name = "Software Hub";    Desc = "AdminWorks updater, Winget package updater, WinToys, VLC & SysAdmin Bundles" },
    @{ Id = "Admin";     Icon = $UI.Admin;    Name = "Admin Utilities"; Desc = "Master GodMode, License audit, Open shares & Windows Admin Consoles" }
)

function Select-Tab($TargetId) {
    $script:CurrentTabId = $TargetId
    $SearchBox.Text = $SearchPlaceholder
    $SearchBox.ForeColor = $script:Theme.TextSubtle
    foreach ($k in $script:CategoryPanels.Keys) { $script:CategoryPanels[$k].Visible = ($k -eq $TargetId) }
    foreach ($card in $script:AllCards) { $card.Panel.Visible = $true }
    foreach ($item in $script:SidebarItems.Values) { 
        $item.Panel.BackColor = $script:Theme.Sidebar
        $item.Indicator.Visible = $false
        $item.Icon.ForeColor = $script:Theme.TextMuted
        $item.Text.ForeColor = $script:Theme.TextMuted
    }
    $active = $script:SidebarItems[$TargetId]
    if ($active) {
        $active.Panel.BackColor = $script:Theme.SidebarActive
        $active.Indicator.Visible = $true
        $active.Icon.ForeColor = $script:Theme.AccentGlow
        $active.Text.ForeColor = [System.Drawing.Color]::White
    }
    Update-ResponsiveLayout
}

[int]$BtnY = 8
foreach ($tab in $TabList) {
    $Flow = New-Object System.Windows.Forms.FlowLayoutPanel -Property @{
        Dock = "Fill"; AutoScroll = $true; BackColor = $script:Theme.Bg; Padding = New-Object System.Windows.Forms.Padding(16, 10, 16, 16); Visible = $false
        WrapContents = $true; FlowDirection = "LeftToRight"
    }
    $ViewContainer.Controls.Add($Flow)
    $script:CategoryPanels[$tab.Id] = $Flow

    $Banner = New-Object System.Windows.Forms.Panel -Property @{ Height = 34; Width = 800; BackColor = [System.Drawing.Color]::Transparent; Margin = New-Object System.Windows.Forms.Padding(6, 6, 6, 10); Tag = "Banner" }
    $BannerIcon  = New-Object System.Windows.Forms.Label -Property @{ Text = $tab.Icon; Location = New-Object System.Drawing.Point(2, 4); Size = New-Object System.Drawing.Size(24, 24); ForeColor = $script:Theme.AccentGlow; Font = New-Object System.Drawing.Font($IconFont, 11); UseMnemonic = $false }
    $BannerTitle = New-Object System.Windows.Forms.Label -Property @{ Text = $tab.Name.ToUpper(); Location = New-Object System.Drawing.Point(28, 4); AutoSize = $true; ForeColor = $script:Theme.TextMain; Font = New-Object System.Drawing.Font($GlobalFont, 10.5, [System.Drawing.FontStyle]::Bold); UseMnemonic = $false }
    $BannerDesc  = New-Object System.Windows.Forms.Label -Property @{ Text = "— $($tab.Desc)"; Location = New-Object System.Drawing.Point(180, 6); AutoSize = $true; ForeColor = $script:Theme.TextSubtle; Font = New-Object System.Drawing.Font($GlobalFont, 8.5); UseMnemonic = $false }
    $Banner.Controls.AddRange(@($BannerIcon, $BannerTitle, $BannerDesc))
    $Banner.Add_Layout({ if ($BannerTitle -and $BannerDesc) { $BannerDesc.Left = $BannerTitle.Right + 8 } })
    $Flow.Controls.Add($Banner)
    $Flow.SetFlowBreak($Banner, $true)

    try {
        
        [void][NativeMethods]::SetWindowTheme($Flow.Handle, "DarkMode_Explorer", $null)
    } catch {}

    $Flow.Add_HandleCreated({
        try {
            
            [void][NativeMethods]::SetWindowTheme($this.Handle, "DarkMode_Explorer", $null)
        } catch {}
    })
    Enable-DoubleBuffering $Flow
    $Flow.HorizontalScroll.Enabled = $false; $Flow.HorizontalScroll.Visible = $false; $Flow.HorizontalScroll.Maximum = 0

    $hideHorizontalScrollBar = {
        param($s, $e)
        $s.HorizontalScroll.Enabled = $false; $s.HorizontalScroll.Visible = $false; $s.HorizontalScroll.Maximum = 0
        try { [void][NativeMethods]::ShowScrollBar($s.Handle, 0, $false) } catch {}
    }
    $Flow.Add_Paint($hideHorizontalScrollBar); $Flow.Add_Layout($hideHorizontalScrollBar)
    $Flow.Add_MouseEnter({ if ($this.CanFocus) { [void]$this.Focus() } })

    # WinUI 3 Navigation item with rounded corners and selection capsule pill
    $ItemPanel = New-Object System.Windows.Forms.Panel -Property @{
        Location = New-Object System.Drawing.Point(8, $BtnY); Size = New-Object System.Drawing.Size(248, 38)
        BackColor = $script:Theme.Sidebar; Cursor = [System.Windows.Forms.Cursors]::Hand; Tag = $tab.Id
    }

    # Vertical selection pill indicator (WinUI 3 style)
    $Indicator = New-Object System.Windows.Forms.Panel -Property @{
        Location = New-Object System.Drawing.Point(2, 9); Size = New-Object System.Drawing.Size(3, 20)
        BackColor = $script:Theme.Accent; Visible = $false
    }

    $IconLbl   = New-Object System.Windows.Forms.Label -Property @{ Text = $tab.Icon; Location = New-Object System.Drawing.Point(16, 9); Size = New-Object System.Drawing.Size(22, 20); ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($IconFont, 10); BackColor = [System.Drawing.Color]::Transparent; UseMnemonic = $false }
    $TextLbl   = New-Object System.Windows.Forms.Label -Property @{ Text = $tab.Name; Location = New-Object System.Drawing.Point(44, 9); Size = New-Object System.Drawing.Size(160, 20); ForeColor = $script:Theme.TextMuted; Font = New-Object System.Drawing.Font($GlobalFont, 8.5, [System.Drawing.FontStyle]::Bold); BackColor = [System.Drawing.Color]::Transparent; AutoEllipsis = $true; UseMnemonic = $false }
    $BadgeLbl  = New-Object System.Windows.Forms.Label -Property @{ Text = ""; Location = New-Object System.Drawing.Point(208, 11); Size = New-Object System.Drawing.Size(34, 16); ForeColor = $script:Theme.TextSubtle; Font = New-Object System.Drawing.Font($GlobalFont, 7, [System.Drawing.FontStyle]::Bold); BackColor = [System.Drawing.Color]::Transparent; TextAlign = "MiddleRight"; UseMnemonic = $false }

    $ItemPanel.Controls.AddRange(@($Indicator, $IconLbl, $TextLbl, $BadgeLbl))
    $ItemPanel.Add_Click({ Select-Tab $this.Tag })
    $IconLbl.Add_Click({ Select-Tab $this.Parent.Tag })
    $TextLbl.Add_Click({ Select-Tab $this.Parent.Tag })
    $ItemPanel.Add_MouseEnter({ if ($script:CurrentTabId -ne $this.Tag) { $this.BackColor = $script:Theme.SidebarHover } })
    $ItemPanel.Add_MouseLeave({ if ($script:CurrentTabId -ne $this.Tag) { $this.BackColor = $script:Theme.Sidebar } })
    $Sidebar.Controls.Add($ItemPanel)
    $script:SidebarItems[$tab.Id] = @{ Panel = $ItemPanel; Indicator = $Indicator; Icon = $IconLbl; Text = $TextLbl; Badge = $BadgeLbl }
    $BtnY += 42
}

$SearchBox.Add_TextChanged({
    $Query = $SearchBox.Text.Trim().ToLower()
    $isSearching = ($Query -ne $SearchPlaceholder.ToLower() -and -not [string]::IsNullOrWhiteSpace($Query))
    if (-not $isSearching) {
        foreach ($card in $script:AllCards) { $card.Panel.Visible = $true }
        foreach ($k in $script:CategoryPanels.Keys) { $script:CategoryPanels[$k].Visible = ($k -eq $script:CurrentTabId) }
        if ($SearchCountLbl) { $SearchCountLbl.Visible = $false }
        foreach ($k in $script:SidebarItems.Keys) {
            $item = $script:SidebarItems[$k]
            $totalInTab = ($script:CategoryPanels[$k].Controls | Where-Object { ($_ -is [System.Windows.Forms.Panel] -or $_ -is [Win11CardPanel]) -and $_.Tag -ne "Banner" }).Count
            if ($item.Badge) { $item.Badge.Text = "$totalInTab"; $item.Badge.ForeColor = $script:Theme.TextSubtle }
            if ($k -eq $script:CurrentTabId) {
                $item.Panel.BackColor = $script:Theme.SidebarActive; $item.Indicator.Visible = $true; $item.Icon.ForeColor = $script:Theme.AccentGlow; $item.Text.ForeColor = [System.Drawing.Color]::White
            } else {
                $item.Panel.BackColor = $script:Theme.Sidebar; $item.Indicator.Visible = $false; $item.Icon.ForeColor = $script:Theme.TextMuted; $item.Text.ForeColor = $script:Theme.TextMuted
            }
        }
        Update-ResponsiveLayout
        return
    }
    $firstMatchTab = $null; $tabMatchCounts = @{}
    foreach ($card in $script:AllCards) {
        $Match = ($card.Title.ToLower() -like "*$Query*") -or ($card.Description.ToLower() -like "*$Query*") -or ($card.Category.ToLower() -like "*$Query*")
        $card.Panel.Visible = $Match
    }
    foreach ($k in $script:CategoryPanels.Keys) {
        $count = ($script:CategoryPanels[$k].Controls | Where-Object { ($_ -is [System.Windows.Forms.Panel] -or $_ -is [Win11CardPanel]) -and $_.Visible -and $_.Tag -ne "Banner" }).Count
        $tabMatchCounts[$k] = $count
        if ($count -gt 0 -and -not $firstMatchTab) { $firstMatchTab = $k }
    }
    foreach ($k in $script:SidebarItems.Keys) {
        $item = $script:SidebarItems[$k]; $matchNum = $tabMatchCounts[$k]
        if ($item.Badge) { $item.Badge.Text = "$matchNum"; $item.Badge.ForeColor = if ($matchNum -gt 0) { $script:Theme.AccentGlow } else { $script:Theme.TextSubtle } }
        $item.Icon.ForeColor = if ($matchNum -gt 0) { $script:Theme.AccentGlow } else { $script:Theme.TextSubtle }
        $item.Text.ForeColor = if ($matchNum -gt 0) { [System.Drawing.Color]::White } else { $script:Theme.TextSubtle }
    }
    $targetTab = $script:CurrentTabId
    if ($tabMatchCounts[$script:CurrentTabId] -eq 0 -and $firstMatchTab) { $targetTab = $firstMatchTab; $script:CurrentTabId = $targetTab }
    foreach ($k in $script:CategoryPanels.Keys) { $script:CategoryPanels[$k].Visible = ($k -eq $targetTab) }
    [int]$totalMatched = ($tabMatchCounts.Values | Measure-Object -Sum).Sum
    if ($SearchCountLbl) { $SearchCountLbl.Text = "$totalMatched found"; $SearchCountLbl.Visible = $true }
    foreach ($k in $script:SidebarItems.Keys) {
        $item = $script:SidebarItems[$k]
        if ($k -eq $targetTab) { $item.Panel.BackColor = $script:Theme.SidebarActive; $item.Indicator.Visible = $true }
        else { $item.Panel.BackColor = $script:Theme.Sidebar; $item.Indicator.Visible = $false }
    }
    Update-ResponsiveLayout
})

# ==================== TABS CONTENT DEFINITIONS ====================
$P_Maint = $script:CategoryPanels["Maint"]
New-TweakCard $P_Maint $UI.Maint "Deep System Repair" "DISM & SFC" "Executes DISM Component Cleanup and System File Checker (SFC) integrity restoration." {
    Write-Log "Beginning DISM /Online /Cleanup-Image /RestoreHealth..." "Warning"
    DISM /Online /Cleanup-Image /RestoreHealth | ForEach-Object { Write-Log $_ "Info" }
    Write-Log "Running System File Checker (sfc /scannow)..." "Warning"
    sfc /scannow | ForEach-Object { Write-Log $_ "Info" }
    Write-Log "System file integrity check complete." "Success"
}
New-TweakCard $P_Maint $UI.Maint "Clean Component Store" "WinSxS Reduction" "Shrinks WinSxS store with /StartComponentCleanup /ResetBase." {
    Write-Log "Shrinking WinSxS component store..." "Warning"
    DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase | ForEach-Object { Write-Log $_ "Info" }
    Write-Log "WinSxS Component store pruned." "Success"
}
New-TweakCard $P_Maint $UI.Refresh "Reset Windows Update" "Update Repair" "Purges stuck SoftwareDistribution & Catroot2 caches and restarts services." {
    Write-Log "Halting Windows Update & cryptographic services..." "Warning"
    Stop-Service -Name "wuauserv", "bits", "cryptsvc" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 600
    Remove-Item "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\System32\catroot2\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name "wuauserv", "bits", "cryptsvc" -ErrorAction SilentlyContinue
    Write-Log "Windows Update cache reset and services restarted." "Success"
}
New-TweakCard $P_Maint $UI.Context "Rebuild Icon & Font Cache" "Explorer Repair" "Clears corrupted thumbnail, font, and Windows Explorer icon databases." {
    Write-Log "Rebuilding icon and font cache..." "Exec"
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache*" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 700
    Start-Process explorer.exe
    Write-Log "Icon and font caches purged and rebuilt." "Success"
}
New-TweakCard $P_Maint $UI.Disk "Clear Delivery Optimization" "Disk Reclaim" "Purges residual Windows Update peer-to-peer delivery caches to free gigabytes." {
    Write-Log "Purging Delivery Optimization cache..." "Exec"
    try {
        if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) {
            Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue
        } else {
            Stop-Service dosvc -Force -ErrorAction SilentlyContinue
            Remove-Item "$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
            Start-Service dosvc -ErrorAction SilentlyContinue
        }
        Write-Log "Delivery Optimization cache purged." "Success"
    } catch { Write-Log "Could not clear Delivery Optimization cache: $($_.Exception.Message)" "Warning" }
}
New-TweakCard $P_Maint $UI.Admin "Repair WMI Repository" "WMI Fix" "Verifies and repairs corrupt Windows Management Instrumentation (WMI) repositories." {
    winmgmt /verifyrepository | ForEach-Object { Write-Log $_ "Info" }
    winmgmt /salvagerepository | ForEach-Object { Write-Log $_ "Warning" }
    Write-Log "WMI repository salvaged and verified." "Success"
}
New-TweakCard $P_Maint $UI.Maint "Reset Print Spooler" "Printer Fix" "Clears stuck printer queue files and restarts the Print Spooler service." {
    Stop-Service Spooler -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemRoot\System32\Spool\Printers\*" -Force -ErrorAction SilentlyContinue
    Start-Service Spooler -ErrorAction SilentlyContinue
    Write-Log "Print Spooler reset and queue cleared." "Success"
}
New-TweakCard $P_Maint $UI.Admin "Purge Windows Event Logs" "Log Cleaner" "Clears all Application, System, Security, and Setup event logs to free space." {
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Are you sure you want to clear all Windows Event Logs (Application, System, Security, etc.)? This action is irreversible.",
        "Confirm Event Log Purge",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-Log "Event Log purge cancelled by user." "Info"
        return
    }
    Write-Log "Purging all Windows Event Logs..." "Exec"
    Get-WinEvent -ListLog * -Force -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 } | ForEach-Object {
        try { [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($_.LogName); Write-Log "Cleared: $($_.LogName)" "Info" } catch {}
    }
    Write-Log "Windows Event Logs purge completed." "Success"
}
New-TweakCard $P_Maint $UI.Disk "Empty All Recycle Bins" "Disk Reclaim" "Purges deleted files in the Recycle Bin across all local and removable volumes." {
    Write-Log "Emptying Recycle Bin on all drives..." "Exec"
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Log "Recycle Bins emptied successfully." "Success"
}
New-TweakCard $P_Maint $UI.Refresh "Rebuild Windows Search Index" "Search Fix" "Stops search service, resets index catalog database, and forces rebuild." {
    Write-Log "Resetting Windows Search indexing database..." "Warning"
    Stop-Service wsearch -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Search" -Name "SetupCompletedSuccessfully" -Value 0 -ErrorAction SilentlyContinue
    Start-Service wsearch -ErrorAction SilentlyContinue
    Write-Log "Windows Search indexing service reset and catalog rebuilding." "Success"
}

$P_Perf = $script:CategoryPanels["Perf"]
New-TweakCard $P_Perf $UI.Perf "Ultimate Power Plan" "Power Scheme" "Unlocks and activates the hidden Windows Ultimate Performance power plan." {
    Set-PowerSchemeUltimate
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" 
    Write-Log "Ultimate Performance power plan applied." "Success"
}
New-TweakCard $P_Perf $UI.Sparkle "Visual Responsiveness" "UI Boost" "Disables window animations, fading effects, and acrylic transparency for max FPS without clobbering font smoothing." {
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f | Out-Null
    reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f | Out-Null
    Write-Log "Visual latency minimized and UI animations disabled." "Success"
}
New-TweakCard $P_Perf $UI.Cpu "Foreground CPU Boost" "Thread Priority" "Configures Win32PrioritySeparation to prioritize foreground applications." {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f | Out-Null
    Write-Log "Foreground app priority separation optimized (Value: 38)." "Success"
}
New-RegToggle $P_Perf $UI.Sparkle "Kill GameDVR & Capture" "Gaming Latency" "Disables Xbox GameDVR background screen recording to eliminate micro-stuttering." `
    "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0 1
New-ToggleCard $P_Perf $UI.Disk "Compact OS Compression" "Storage & Power" "Toggles Windows 11 Compact OS system binary compression to save 4-8 GB SSD storage with near-zero latency impact." `
    { ((compact /compactos:query 2>$null) -match "is in the compact state") } `
    {
        compact /compactos:always 2>&1 | ForEach-Object { Write-Log $_ "Info" }
        Write-Log "Compact OS compression enabled." "Success"
    } `
    {
        compact /compactos:never 2>&1 | ForEach-Object { Write-Log $_ "Info" }
        Write-Log "Compact OS compression disabled." "Warning"
    }
New-ToggleCard $P_Perf $UI.Disk "Disable Hibernation" "Storage & Power" "Runs 'powercfg -h off' to eliminate hiberfil.sys and free gigabytes of drive space." `
    { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -ErrorAction SilentlyContinue).HibernateEnabled -eq 0 -or -not (Test-Path "$env:SystemDrive\hiberfil.sys") } `
    { powercfg -h off; Write-Log "Hibernation disabled (hiberfil.sys removed)." "Success" } `
    { powercfg -h on; Write-Log "Hibernation enabled (hiberfil.sys restored)." "Warning" }
New-TweakCard $P_Perf $UI.Hardware "Disable USB Suspend" "Hardware Latency" "Disables USB Selective Suspend to prevent disconnects on peripherals." {
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a84c312-a001-40c3-b31f-1393d254d070 48e6b7a6-50f2-4389-a784-1779c7b048db 0 2>$null
    powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a84c312-a001-40c3-b31f-1393d254d070 48e6b7a6-50f2-4389-a784-1779c7b048db 0 2>$null
    powercfg /setactive SCHEME_CURRENT 2>$null
    Write-Log "USB Selective Suspend disabled (AC & DC)." "Success"
}
New-RegToggle $P_Perf $UI.Display "Auto HDR for Gaming" "DirectX Gaming" "Toggles system-wide Auto HDR for DirectX 11 and 12 games on compatible displays." `
    "HKCU:\Software\Microsoft\Direct3D" "EnableAutoHDR" 1 0
New-ToggleCard $P_Perf $UI.Sparkle "Windowed Game Latency" "Gaming Boost" "Upgrades presentation model for windowed games in Windows 11 to minimize latency & enable VRR." `
    { (Get-ItemProperty "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -ErrorAction SilentlyContinue).DirectXUserGlobalSettings -like "*SwapEffectUpgradeEnable=1*" } `
    { reg add "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" /v "DirectXUserGlobalSettings" /t REG_SZ /d "SwapEffectUpgradeEnable=1;" /f | Out-Null; Write-Log "Windowed Game Optimizations enabled." "Success" } `
    { reg delete "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" /v "DirectXUserGlobalSettings" /f 2>$null | Out-Null; Write-Log "Windowed Game Optimizations restored to default." "Warning" }
New-TweakCard $P_Perf $UI.Shield "Core Isolation (HVCI) Audit" "Security & VBS" "Audits Virtualization-Based Security (VBS) and Hypervisor-Enforced Code Integrity (Memory Integrity)." {
    Write-Log "Auditing Windows 11 Virtualization-Based Security (VBS)..." "Exec"
    $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue
    if ($dg) {
        $vbsStatus = switch ($dg.VirtualizationBasedSecurityStatus) { 0 { "Disabled" } 1 { "Enabled (Configured)" } 2 { "Running (Active)" } Default { "Unknown" } }
        Write-Log "VBS Security Status: $vbsStatus" (if ($dg.VirtualizationBasedSecurityStatus -eq 2) { "Success" } else { "Warning" })
        $hvci = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -ErrorAction SilentlyContinue).Enabled
        Write-Log "Memory Integrity (HVCI): $(if ($hvci -eq 1) { 'Enabled (Active)' } else { 'Disabled' })" (if ($hvci -eq 1) { "Success" } else { "Info" })
    } else { Write-Log "DeviceGuard VBS provider not accessible." "Warning" }
}

$P_Net = $script:CategoryPanels["Net"]
New-TweakCard $P_Net $UI.Net "Reset Network Stack" "Network Repair" "Performs full TCP/IP reset, Winsock catalog repair, and DNS cache flush." {
    Write-Log "Resetting network adapters & Winsock stack..." "Warning"
    ipconfig /flushdns | Out-Null; netsh int ip reset | Out-Null; netsh winsock reset | Out-Null
    Write-Log "Network stack successfully reset. (Reboot recommended)" "Success"
}
@(
    @{ Name="Cloudflare DNS (1.1.1.1)"; IP1="1.1.1.1"; IP2="1.0.0.1"; Doh="https://cloudflare-dns.com/dns-query"; Desc="Sets primary and secondary DNS on all active network adapters to Cloudflare with DNS-over-HTTPS." },
    @{ Name="Google DNS (8.8.8.8)";     IP1="8.8.8.8"; IP2="8.8.4.4"; Doh="https://dns.google/dns-query";          Desc="Sets primary and secondary DNS on all active network adapters to Google Public DNS with DNS-over-HTTPS." }
) | ForEach-Object {
    $dns = $_
    $ip1 = $dns.IP1; $ip2 = $dns.IP2; $dName = $dns.Name; $doh = $dns.Doh
    $dnsCode = @"
Get-NetAdapter | Where-Object { `$_.Status -eq 'Up' } | ForEach-Object {
    Set-DnsClientServerAddress -InterfaceAlias `$_.Name -ServerAddresses ('$ip1', '$ip2')
    try {
        if (Get-Command Set-DnsClientDohServerAddress -ErrorAction SilentlyContinue) {
            Set-DnsClientDohServerAddress -ServerAddress '$ip1' -DohTemplate '$doh' -AllowFallbackToUdp `$false -AutoUpgrade `$true -ErrorAction SilentlyContinue
        }
    } catch {}
    Write-Log "Set $dName on adapter: `$(`$_.Name) (DoH configured)" "Success"
}
"@
    New-TweakCard $P_Net $UI.Net $dns.Name "DNS Switcher" $dns.Desc $dnsCode
}
New-TweakCard $P_Net $UI.Refresh "Restore Automatic DNS" "DNS Reset" "Reverts all active network interfaces to obtain DNS dynamically via DHCP." {
    Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
        Set-DnsClientServerAddress -InterfaceAlias $_.Name -ResetServerAddresses
        Write-Log "Restored DHCP DNS on: $($_.Name)" "Success"
    }
}
New-TweakCard $P_Net $UI.Perf "DNS Benchmark Test" "Diagnostics" "Pings Cloudflare, Google, Quad9, and OpenDNS to find lowest latency provider." {
    Write-Log "Benchmarking DNS latency..." "Exec"
    @(
        @{ Name="Cloudflare"; IP="1.1.1.1" }, @{ Name="Google"; IP="8.8.8.8" },
        @{ Name="Quad9"; IP="9.9.9.9" }, @{ Name="OpenDNS"; IP="208.67.222.222" }
    ) | ForEach-Object {
        $test = Test-Connection -ComputerName $_.IP -Count 3 -ErrorAction SilentlyContinue
        if ($test) {
            $avg = [math]::Round(($test | Measure-Object -Property ResponseTime -Average).Average, 1)
            Write-Log "$($_.Name) ($($_.IP)): Avg Latency = $avg ms" "Success"
        } else { Write-Log "$($_.Name) ($($_.IP)): 100% Packet Loss" "Error" }
    }
}
New-TweakCard $P_Net $UI.Privacy "Wi-Fi Profiles & Security Audit" "Security & Keys" "Audits all saved wireless network profiles, authentication types, and ciphers." {
    Write-Log "Auditing saved Wi-Fi profiles..." "Exec"
    $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { ($_ -split ":")[-1].Trim() }
    if ($profiles) {
        foreach ($prof in $profiles) {
            $details = netsh wlan show profile name="$prof"
            $auth = ($details | Select-String "Authentication" | Select-Object -First 1) -replace ".*:\s*", ""
            $cipher = ($details | Select-String "Cipher" | Select-Object -First 1) -replace ".*:\s*", ""
            Write-Log "SSID: '$prof' | Auth: $auth | Cipher: $cipher" "Success"
        }
    } else { Write-Log "No Wi-Fi profiles found." "Warning" }
}
New-TweakCard $P_Net $UI.Hardware "Scan LAN Subnet Devices" "Network Discovery" "Sweeps the local subnet and lists active IP and MAC addresses." {
    Write-Log "Discovering LAN devices on local subnet..." "Exec"
    $arp = arp -a | Select-String "dynamic"
    foreach ($line in $arp) {
        $parts = $line.Line.Trim() -split "\s+"
        if ($parts.Count -ge 2) { Write-Log "Active Host: IP $($parts[0]) | MAC $($parts[1])" "Info" }
    }
    Write-Log "Subnet discovery complete." "Success"
}
New-TweakCard $P_Net $UI.Admin "Port & Process Listeners" "Network Security" "Scans active listening TCP ports and maps them to host application executables." {
    Write-Log "Auditing listening ports & processes..." "Exec"
    $procMap = @{}
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object { $procMap[$_.Id] = $_.Name }
    Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
        $pName = if ($procMap.ContainsKey($_.OwningProcess)) { $procMap[$_.OwningProcess] } else { "System/Unknown" }
        Write-Log "Port $($_.LocalPort) ($($_.LocalAddress)) -> $pName (PID $($_.OwningProcess))" "Info"
    }
    Write-Log "Port audit complete." "Success"
}
New-TweakCard $P_Net $UI.Net "Public IP & Geo-Location" "WAN Diagnostics" "Queries external routing APIs to retrieve WAN IP, ISP, ASN, and city location." {
    Write-Log "Resolving Public WAN IP & ISP..." "Exec"
    try {
        $info = Invoke-RestMethod -Uri "https://ipinfo.io/json" -TimeoutSec 4
        Write-Log "Public IP: $($info.ip) | ISP: $($info.org)" "Success"
        Write-Log "Location: $($info.city), $($info.region), $($info.country)" "Info"
    } catch { Write-Log "Failed to reach IP resolution service. Check internet connectivity." "Error" }
}
New-ToggleCard $P_Net $UI.Shield "Remote Desktop (RDP)" "Remote Admin" "Toggles Windows Terminal Server RDP listener and firewall exception rule." `
    { (Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -ErrorAction SilentlyContinue).fDenyTSConnections -eq 0 } `
    {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
        try { Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue } catch {}
        try { Enable-NetFirewallRule -Name "RemoteDesktop*" -ErrorAction SilentlyContinue } catch {}
        Write-Log "Remote Desktop (RDP) enabled and firewall opened." "Success"
    } `
    {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 1
        try { Disable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue } catch {}
        try { Disable-NetFirewallRule -Name "RemoteDesktop*" -ErrorAction SilentlyContinue } catch {}
        Write-Log "Remote Desktop (RDP) disabled." "Warning"
    }

$P_Privacy = $script:CategoryPanels["Privacy"]
New-TweakCard $P_Privacy $UI.Apps "Universal OEM Debloat" "App Purge" "Removes consumer bloatware (TikTok, CandyCrush, McAfee, Netflix, DevHome, etc.)." {
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Are you sure you want to remove pre-installed third-party consumer packages?`n`nPackages targeted include Spotify, Netflix, TikTok, McAfee, DevHome, etc.",
        "Confirm Universal Debloat",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-Log "Universal Debloat cancelled by user." "Info"
        return
    }
    $Apps = @(
        "*TikTok*", "*Instagram*", "*Facebook*", "*LinkedIn*", "*Twitter*", "*WhatsApp*",
        "*Disney*", "*PrimeVideo*", "*Spotify*", "*Netflix*", "*Hulu*", "*CandyCrush*",
        "*BubbleWitch*", "*MarchOfEmpires*", "*HiddenCity*", "*Asphalt*", "*MinecraftUWP*",
        "*McAfee*", "*Norton*", "*Dropbox*", "*Evernote*", "*Clipchamp*", "*BingNews*",
        "*BingFinance*", "*BingSports*", "*DevHome*", "*OutlookForWindows*", "*Copilot*",
        "*QuickAssist*", "*Todos*", "*PowerAutomateDesktop*", "*FeedbackHub*"
    )
    [int]$count = 0
    $provPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    foreach ($app in $Apps) {
        $installed = Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue
        if ($installed) {
            $installed | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            if ($provPackages) {
                $provPackages | Where-Object { $_.DisplayName -like $app -or $_.PackageName -like $app } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            }
            Write-Log "Removed: $app" "Success"
            $count++
        }
    }
    Write-Log "$count bloatware packages purged." "Success"
}
New-ToggleCard $P_Privacy $UI.Search "Disable Copilot & Web Search" "Search & AI" "Toggles Windows Copilot, Taskbar Widgets, and Start Menu Bing Web search." `
    { (Get-ItemProperty 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' -ErrorAction SilentlyContinue).TurnOffWindowsCopilot -eq 1 } `
    {
        reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarDa" /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v "DisableSearchBoxSuggestions" /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings" /v "IsDynamicSearchBoxEnabled" /t REG_DWORD /d 0 /f | Out-Null
        Restart-Explorer
        Write-Log "Windows Copilot, Widgets, and Start Web Search disabled." "Success"
    } `
    {
        reg delete "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /f 2>$null | Out-Null
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarDa" /t REG_DWORD /d 1 /f | Out-Null
        reg delete "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v "DisableSearchBoxSuggestions" /f 2>$null | Out-Null
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings" /v "IsDynamicSearchBoxEnabled" /t REG_DWORD /d 1 /f | Out-Null
        Restart-Explorer
        Write-Log "Windows Copilot and Search Suggestions restored." "Warning"
    }
New-TweakCard $P_Privacy $UI.Privacy "Disable Recall & AI Tracking" "Privacy" "Disables Windows 11 Recall AI screen recording, snapshots, and background image analysis." {
    if (Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue) {
        Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Write-Log "Windows Recall AI feature uninstalled/removed." "Success"
    } else { Write-Log "Windows Recall feature not present on this package image." "Info" }
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v "DisableAIDataAnalysis" /t REG_DWORD /d 1 /f | Out-Null
    Write-Log "Windows Recall and AI telemetry policies disabled." "Success"
}
New-RegToggle $P_Privacy $UI.Shield "Disable AI Data Analysis" "Windows 11 AI" "Toggles system-wide model training, telemetry feedback, and diagnostic AI analysis policies." `
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1 0
New-ToggleCard $P_Privacy $UI.Shield "Kill Telemetry & DiagTrack" "Privacy" "Toggles Connected User Experiences (DiagTrack), dmwappushservice, and telemetry." `
    { (Get-Service "DiagTrack" -ErrorAction SilentlyContinue).StartType -eq "Disabled" } `
    {
        Stop-Service "DiagTrack", "dmwappushservice" -ErrorAction SilentlyContinue
        Set-Service "DiagTrack", "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /t REG_DWORD /d 0 /f | Out-Null
        Write-Log "Diagnostic data and telemetry logging disabled." "Success"
    } `
    {
        Set-Service "DiagTrack", "dmwappushservice" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service "DiagTrack" -ErrorAction SilentlyContinue
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /f 2>$null | Out-Null
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v "TailoredExperiencesWithDiagnosticDataEnabled" /t REG_DWORD /d 1 /f | Out-Null
        Write-Log "Telemetry services restored." "Warning"
    }
New-TweakCard $P_Privacy $UI.Shield "Block Telemetry via Firewall" "Security" "Creates outbound Windows Defender Firewall rules blocking telemetry endpoints." {
    Write-Log "Applying Windows Defender Firewall outbound telemetry block rules..." "Exec"
    $ruleName = "AdminWorks_BlockTelemetry"
    $targets = @("telemetry.microsoft.com", "v10.events.data.microsoft.com", "browser.events.data.msn.com", "watson.telemetry.microsoft.com")
    $ips = @()
    foreach ($t in $targets) {
        try {
            $resolved = [System.Net.Dns]::GetHostAddresses($t) | ForEach-Object { $_.IPAddressToString }
            if ($resolved) { $ips += $resolved }
        } catch {}
    }
    $ips = $ips | Select-Object -Unique
    if ($ips.Count -gt 0) {
        try {
            Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
            New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Action Block -RemoteAddress $ips -Description "AdminWorks automated telemetry endpoint block rule" | Out-Null
            Write-Log "Firewall rule '$ruleName' active ($($ips.Count) endpoints blocked)." "Success"
        } catch { Write-Log "Firewall configuration error: $($_.Exception.Message)" "Warning" }
    } else { Write-Log "Could not resolve telemetry IP targets. Check network connection." "Warning" }
}
New-RegToggle $P_Privacy $UI.Privacy "Lock Screen Spotlight & Ads" "UI Cleanup" "Toggles dynamic promotional suggestions, lockscreen tips, and feedback notifications." `
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled" 0 1
New-RegToggle $P_Privacy $UI.Admin "Activity History & Timeline" "Privacy" "Toggles local Windows application activity tracking and cloud telemetry sync." `
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0 1

$P_Context = $script:CategoryPanels["Context"]
New-ToggleCard $P_Context $UI.Context "Classic Context Menu" "Context Menu" "Toggles the Windows 10 full right-click context menu without 'Show more options'." `
    { Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" } `
    { reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve | Out-Null; Restart-Explorer; Write-Log "Classic Context Menu enabled." "Success" } `
    { reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f 2>$null | Out-Null; Restart-Explorer; Write-Log "Windows 11 Modern Context Menu restored." "Warning" }
New-ToggleCard $P_Context $UI.Admin "Add 'Take Ownership'" "Context Menu" "Toggles a 'Take Ownership' option on file and folder right-click menus." `
    { (Test-Path "HKCR:\*\shell\TakeOwnership") -and (Test-Path "HKCR:\Directory\shell\TakeOwnership") } `
    {
        foreach ($p in @("HKCR:\*\shell\TakeOwnership", "HKCR:\Directory\shell\TakeOwnership")) {
            New-Item -Path $p -Force | Out-Null; Set-ItemProperty -Path $p -Name "(Default)" -Value "Take Ownership"
            Set-ItemProperty -Path $p -Name "HasLUAShield" -Value ""; New-Item -Path "$p\command" -Force | Out-Null
        }
        Set-ItemProperty -Path "HKCR:\*\shell\TakeOwnership\command" -Name "(Default)" -Value 'cmd.exe /c takeown /f "%1" && icacls "%1" /grant administrators:F'
        Set-ItemProperty -Path "HKCR:\Directory\shell\TakeOwnership\command" -Name "(Default)" -Value 'cmd.exe /c takeown /f "%1" /r /d y && icacls "%1" /grant administrators:F /t'
        Write-Log "Take Ownership context menu shortcut added." "Success"
    } `
    {
        Remove-Item "HKCR:\*\shell\TakeOwnership", "HKCR:\Directory\shell\TakeOwnership" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Take Ownership context menu shortcut removed." "Warning"
    }
New-ToggleCard $P_Context $UI.Admin "Add 'PowerShell Admin Here'" "Context Menu" "Toggles an 'Open PowerShell as Administrator' shortcut on background folder clicks." `
    { Test-Path "HKCR:\Directory\Background\shell\OpenElevatedPS" } `
    {
        $regPath = "HKCR:\Directory\Background\shell\OpenElevatedPS"; New-Item -Path $regPath -Force | Out-Null
        Set-ItemProperty -Path $regPath -Name "(Default)" -Value "Open PowerShell As Admin Here"; Set-ItemProperty -Path $regPath -Name "Icon" -Value "powershell.exe"
        New-Item -Path "$regPath\command" -Force | Out-Null; Set-ItemProperty -Path "$regPath\command" -Name "(Default)" -Value 'powershell.exe -Command "Start-Process powershell -Verb RunAs -WorkingDirectory ''%V''"'
        Write-Log "'Open PowerShell As Admin Here' added." "Success"
    } `
    { Remove-Item "HKCR:\Directory\Background\shell\OpenElevatedPS" -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "'Open PowerShell As Admin Here' removed." "Warning" }
New-ToggleCard $P_Context $UI.Context "File Explorer Pro Mode" "File System" "Toggles file extensions (.exe, .txt), unhides system files, and shows full title paths." `
    { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ErrorAction SilentlyContinue).HideFileExt -eq 0 } `
    {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
        Restart-Explorer; Write-Log "File Explorer configured to show extensions and hidden files." "Success"
    } `
    {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 1
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 2
        Restart-Explorer; Write-Log "File Explorer returned to default view." "Warning"
    }
New-RegToggle $P_Context $UI.Context "Explorer Compact View" "File Explorer" "Toggles dense compact folder row spacing in Windows 11 File Explorer." `
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "UseCompactMode" 1 0 $true
New-RegToggle $P_Context $UI.Context "Taskbar Align Left" "Taskbar Layout" "Toggles Windows 11 taskbar icons between standard Center alignment and classic Left alignment." `
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0 1 $true
New-RegToggle $P_Context $UI.Context "Taskbar Never Combine" "Taskbar Behavior" "Shows individual window labels on the taskbar without combining identical application icons." `
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel" 2 0 $true
New-RegToggle $P_Context $UI.Context "Hide Start Recommendations" "Start Menu" "Hides recommended recent files, newly installed app suggestions, and tips in the Windows 11 Start Menu." `
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecommendedSection" 1 0 $true
New-ToggleCard $P_Context $UI.Context "Hide Widgets & Chat" "Taskbar Items" "Removes the Widgets weather feed and Microsoft Teams Chat icon from the Windows 11 Taskbar." `
    { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ErrorAction SilentlyContinue).TaskbarDa -eq 0 -and (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ErrorAction SilentlyContinue).TaskbarMn -eq 0 } `
    {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0
        Restart-Explorer; Write-Log "Widgets and Chat taskbar icons hidden." "Success"
    } `
    {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 1
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 1
        Restart-Explorer; Write-Log "Widgets and Chat taskbar icons restored." "Warning"
    }

$P_Hw = $script:CategoryPanels["Hardware"]
New-TweakCard $P_Hw $UI.Disk "SMART Disk Health" "Storage Health" "Audits physical drives, media type (NVMe/SSD/HDD), and SMART health statuses." {
    Get-PhysicalDisk | ForEach-Object {
        $st = if ($_.HealthStatus -eq "Healthy") { "Success" } else { "Error" }
        Write-Log "Disk #$($_.DeviceId) ($($_.FriendlyName)): Health=$($_.HealthStatus) | MediaType=$($_.MediaType)" $st
    }
}
New-TweakCard $P_Hw $UI.Ram "RAM Bank & Slot Audit" "Memory Specs" "Inspects physical RAM slots, module capacities, clock speeds, and manufacturers." {
    $sticks = Get-CimInstance Win32_PhysicalMemory; $tot = [math]::Round(($sticks | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
    Write-Log "Total Installed Memory: $tot GB across $($sticks.Count) slots:" "Success"
    foreach ($s in $sticks) {
        $gb = [math]::Round($s.Capacity / 1GB, 2)
        Write-Log "Slot $($s.BankLabel): $gb GB @ $($s.Speed) MHz ($($s.Manufacturer))" "Info"
    }
}
New-TweakCard $P_Hw $UI.Perf "Battery Health Report" "Power Report" "Generates a detailed HTML battery capacity and degradation report on Desktop." {
    $p = Join-Path (Get-UserDesktopPath) "BatteryReport.html"; powercfg /batteryreport /output $p | Out-Null
    Write-Log "Battery Diagnostic report saved to: $p" "Success"
}
New-TweakCard $P_Hw $UI.Hardware "GPU & Display Audit" "Graphics Specs" "Inspects installed GPU adapters, driver versions, and display resolutions." {
    Get-CimInstance Win32_VideoController | ForEach-Object {
        Write-Log "GPU: $($_.Name) - Driver: $($_.DriverVersion) - Res: $($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution) @ $($_.CurrentRefreshRate)Hz" "Success"
    }
}
New-TweakCard $P_Hw $UI.Admin "Motherboard & BIOS Audit" "Firmware Specs" "Retrieves baseboard manufacturer, model, BIOS/UEFI version, and Secure Boot status." {
    Write-Log "Inspecting Motherboard & BIOS/UEFI firmware..." "Exec"
    $bb = Get-CimInstance Win32_BaseBoard; $bios = Get-CimInstance Win32_BIOS
    $sb = try { (Confirm-SecureBootUEFI) } catch { "Unsupported/Legacy" }
    $relDate = if ($bios.ReleaseDate -is [datetime]) { $bios.ReleaseDate.ToString('yyyy-MM-dd') } else { [string]$bios.ReleaseDate }
    Write-Log "Motherboard: $($bb.Manufacturer) $($bb.Product)" "Success"
    Write-Log "BIOS/UEFI: $($bios.SMBIOSBIOSVersion) (Released: $relDate)" "Info"
    Write-Log "Secure Boot State: $sb" "Info"
}
New-TweakCard $P_Hw $UI.Cpu "CPU Virtualization Audit" "CPU Topology" "Checks hardware virtualization flags (VT-x / AMD-V), Hyper-V status, and core topology." {
    Write-Log "Auditing CPU architecture & virtualization..." "Exec"
    $proc = Get-CimInstance Win32_Processor | Select-Object -First 1
    Write-Log "Processor: $($proc.Name)" "Success"
    Write-Log "Cores: $($proc.NumberOfCores) | Threads: $($proc.NumberOfLogicalProcessors) | Max Clock: $($proc.MaxClockSpeed) MHz" "Info"
    Write-Log "Firmware Virtualization Enabled: $($proc.VirtualizationFirmwareEnabled)" "Success"
}
New-TweakCard $P_Hw $UI.Disk "Disk Sector & Partition Audit" "Drive Specs" "Audits physical sector sizes (4Kn vs 512e) and partition tables per disk." {
    Write-Log "Auditing disk geometry & partition styles..." "Exec"
    Get-Disk | ForEach-Object { Write-Log "Disk #$($_.Number): $($_.FriendlyName) | Style: $($_.PartitionStyle) | SectorSize: $($_.PhysicalSectorSize)B" "Info" }
    Write-Log "Storage geometry audit complete." "Success"
}
New-TweakCard $P_Hw $UI.Shield "TPM 2.0 & Platform Security" "Security Hardware" "Audits Trusted Platform Module (TPM 2.0) chip presence, specification version, and Secure Boot state." {
    Write-Log "Auditing TPM 2.0 & Platform Security..." "Exec"
    $tpm = Get-Tpm -ErrorAction SilentlyContinue
    if ($tpm) {
        Write-Log "TPM Present: $($tpm.TpmPresent) | Ready: $($tpm.TpmReady) | Enabled: $($tpm.TpmEnabled)" (if ($tpm.TpmReady) { "Success" } else { "Warning" })
        $tpmVer = (Get-CimInstance -Namespace "root\cimv2\Security\MicrosoftTpm" -ClassName Win32_Tpm -ErrorAction SilentlyContinue).SpecVersion
        if ($tpmVer) { Write-Log "TPM Spec Version: $tpmVer" "Info" }
    } else { Write-Log "TPM module not detected or query restricted." "Warning" }
    $sb = try { Confirm-SecureBootUEFI } catch { "Not Supported" }
    Write-Log "UEFI Secure Boot Status: $sb" (if ($sb -eq $true) { "Success" } else { "Warning" })
}
New-TweakCard $P_Hw $UI.Disk "DirectStorage BypassIO Audit" "Storage Architecture" "Inspects Windows 11 BypassIO status on System Drive (C:) for ultra-fast NVMe game loading." {
    Write-Log "Checking DirectStorage BypassIO storage pipeline on C:..." "Exec"
    try {
        fsutil bypassIo state C: 2>&1 | ForEach-Object {
            if ($_ -match "BypassIo is supported") { Write-Log $_ "Success" }
            elseif ($_ -match "Error|Not supported|Incompatible") { Write-Log $_ "Warning" }
            else { Write-Log $_ "Info" }
        }
    } catch { Write-Log "BypassIO query failed: $($_.Exception.Message)" "Error" }
}

$P_Apps = $script:CategoryPanels["Apps"]
New-TweakCard $P_Apps $UI.Refresh "Update AdminWorks (AdminWorks.exe)" "Software Update" "Downloads and updates AdminWorks.exe from the latest GitHub release (KushagraKarira/AdminWorks)." {
    Update-AdminWorksSuite
}
New-TweakCard $P_Apps $UI.Net "AdminWorks Release Page" "GitHub Releases" "Opens the official GitHub releases page to inspect release notes, changelogs, and binary assets." {
    Start-Process "https://github.com/KushagraKarira/AdminWorks/releases"; Write-Log "Opened GitHub Releases." "Success"
}
New-TweakCard $P_Apps $UI.Apps "Install / Repair Winget" "Package Manager" "Downloads and forces the installation of the latest Microsoft App Installer (Winget)." {
    Write-Log "Downloading latest Winget MSIX Bundle from Microsoft..." "Warning"
    $file = "$env:TEMP\winget.msixbundle"
    try {
        Invoke-WebRequest -Uri "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile $file -UseBasicParsing
        Add-AppxPackage -Path $file -ForceUpdateFromAnyVersion -ErrorAction Stop
        Write-Log "Winget successfully installed/repaired." "Success"
    } catch { Write-Log "Failed to install Winget: $($_.Exception.Message)" "Error" }
}
New-TweakCard $P_Apps $UI.Refresh "Winget Upgrade All Apps" "Package Manager" "Runs winget upgrade --all with auto-accepted package agreements." {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "Winget is missing. Run 'Install / Repair Winget' first." "Error"; return }
    Write-Log "Scanning for package upgrades via Winget..." "Warning"
    winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements | ForEach-Object { if ($_.Trim()) { Write-Log $_ "Info" } }
    Write-Log "Winget package sync complete." "Success"
}
New-TweakCard $P_Apps $UI.Apps "Backup Installed Apps List" "Package Manager" "Exports list of all installed packages via Winget to desktop as JSON." {
    $outPath = Join-Path (Get-UserDesktopPath) "Winget_App_Backup_$((Get-Date).ToString('yyyyMMdd')).json"
    winget export -o "$outPath" --include-versions; Write-Log "Installed apps exported to: $outPath" "Success"
}
@(
    @{ Id="9P8LTPGCBZXD"; Name="WinToys"; Src="msstore"; Cat="Optimization Tools"; Desc="Installs WinToys from the Microsoft Store for advanced Windows customization." },
    @{ Id="VideoLAN.VLC"; Name="VLC Media Player"; Cat="Media Players"; Desc="Installs the open-source VLC Media Player package via Winget." },
    @{ Id="SumatraPDF.SumatraPDF"; Name="Sumatra PDF"; Cat="Productivity"; Desc="Installs the lightweight Sumatra PDF reader package via Winget." },
    @{ Id="Microsoft.PowerToys"; Name="PowerToys"; Cat="Essential Tools"; Desc="Installs Microsoft PowerToys for advanced system utilities and window management." },
    @{ Id="7zip.7zip"; Name="7-Zip"; Cat="Essential Tools"; Desc="Installs the industry-standard 7-Zip file compression utility." },
    @{ Id="Microsoft.SysinternalsSuite"; Name="Sysinternals Suite"; Cat="SysAdmin Tools"; Desc="Installs Microsoft Sysinternals troubleshooting suite via Winget." }
) | ForEach-Object {
    $app = $_
    $appId = $app.Id; $appName = $app.Name; $appSrc = if ($app.Src) { "'$($app.Src)'" } else { "`$null" }
    $appCode = "Install-WingetPackage '$appId' '$appName' $appSrc"
    New-TweakCard $P_Apps $UI.Apps "Install $($app.Name)" $app.Cat $app.Desc $appCode
}
New-TweakCard $P_Apps $UI.Admin "Install Developer Bundle" "Winget Bundle" "Installs Git, VS Code, Windows Terminal, and PowerShell 7 in one batch." {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "Winget is missing." "Error"; return }
    @("Git.Git", "Microsoft.VisualStudioCode", "Microsoft.WindowsTerminal", "Microsoft.PowerShell") | ForEach-Object {
        Write-Log "Installing: $_..." "Exec"; winget install $_ --silent --accept-package-agreements --accept-source-agreements | Out-Null
    }
    Write-Log "Developer Essentials Bundle installed." "Success"
}
New-TweakCard $P_Apps $UI.Shield "Install SysAdmin Bundle" "Winget Bundle" "Installs Wireshark, Nmap, PuTTY, and System Informer in one batch." {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Write-Log "Winget is missing." "Error"; return }
    @("WiresharkFoundation.Wireshark", "Insecure.Nmap", "PuTTY.PuTTY", "Winsiderss.SystemInformer") | ForEach-Object {
        Write-Log "Installing: $_..." "Exec"; winget install $_ --silent --accept-package-agreements --accept-source-agreements | Out-Null
    }
    Write-Log "SysAdmin Diagnostics Bundle installed." "Success"
}
New-TweakCard $P_Apps $UI.Admin "Install / Update WSL 2" "Linux Subsystem" "Installs or updates the Windows Subsystem for Linux (WSL 2) kernel package directly." {
    Write-Log "Checking and updating Windows Subsystem for Linux (WSL 2)..." "Exec"
    wsl --update 2>&1 | ForEach-Object { Write-Log $_ "Info" }
    wsl --status 2>&1 | ForEach-Object { Write-Log $_ "Info" }
    Write-Log "WSL 2 verification complete." "Success"
}

$P_Admin = $script:CategoryPanels["Admin"]
New-TweakCard $P_Admin $UI.Refresh "Check for AdminWorks Updates" "Suite Update" "Checks GitHub Releases (KushagraKarira/AdminWorks) and updates AdminWorks.exe to the latest release." {
    Update-AdminWorksSuite
}
New-TweakCard $P_Admin $UI.Shield "Create System Restore Point" "Safety Checkpoint" "Generates a fresh Windows System Restore point named 'AdminWorks_Checkpoint'." {
    Write-Log "Creating Windows System Restore Point..." "Exec"
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f 2>$null | Out-Null
        Checkpoint-Computer -Description "AdminWorks_Checkpoint" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Restore point created successfully." "Success"
    } catch { Write-Log "Restore Point Error: $($_.Exception.Message)" "Error" }
}
New-TweakCard $P_Admin $UI.Admin "Create GodMode Shortcut" "Master Control" "Creates a master GodMode folder on the Desktop linking to all 200+ control applets." {
    $p = Join-Path (Get-UserDesktopPath) "GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}"
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null; Write-Log "GodMode shortcut created on Desktop." "Success" }
    else { Write-Log "GodMode shortcut already exists." "Warning" }
}
New-TweakCard $P_Admin $UI.Privacy "Audit Local Administrators" "Security Audit" "Lists all members of the local Administrators group for unauthorized access." {
    Write-Log "Auditing local Administrator members..." "Exec"
    Get-LocalGroupMember -Group "Administrators" | ForEach-Object { Write-Log "Admin Member: $($_.Name) ($($_.PrincipalSource))" "Info" }
    Write-Log "Local Administrator audit complete." "Success"
}
New-TweakCard $P_Admin $UI.Net "Audit Active SMB Shares" "Security Audit" "Audits all active network shared folders, admin shares, and paths." {
    Write-Log "Auditing active SMB network shares..." "Exec"
    Get-SmbShare | ForEach-Object { Write-Log "Share '$($_.Name)' -> Path: $($_.Path) [Type: $($_.ShareType)]" "Info" }
    Write-Log "SMB Shares audit complete." "Success"
}
New-TweakCard $P_Admin $UI.Shield "Windows License Audit" "License Status" "Checks Windows digital licensing, product keys, and activation status." {
    Write-Log "Verifying Windows licensing state..." "Exec"
    $lic = Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationId = '55c92734-d682-4d71-983e-d6ec3f16059f' and PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($lic) {
        $st = switch ($lic.LicenseStatus) { 1 { "Licensed" } 2 { "OOB Grace" } 3 { "OOT Grace" } 4 { "Non-Genuine" } 5 { "Notification" } Default { "Unknown" } }
        Write-Log "Product: $($lic.Name)" "Info"
        Write-Log "License Status: $st (Key Channel: $($lic.Description))" "Success"
    } else { Write-Log "Unable to retrieve licensing details." "Warning" }
}
@(
    @{ Cmd="ncpa.cpl";    Name="Network Connections (NCPA)";  Desc="Opens ncpa.cpl to manage network adapters."; Icon=$UI.Net },
    @{ Cmd="sysdm.cpl";   Name="System Properties (SYSDM)";   Desc="Opens sysdm.cpl to configure advanced performance, vars & computer name."; Icon=$UI.Hardware },
    @{ Cmd="devmgmt.msc"; Name="Launch Device Manager";        Desc="Opens devmgmt.msc directly to inspect hardware drivers."; Icon=$UI.Hardware },
    @{ Cmd="services.msc";Name="Launch Services Console";      Desc="Opens services.msc to inspect and configure background services."; Icon=$UI.Admin },
    @{ Cmd="eventvwr.msc";Name="Launch Event Viewer";          Desc="Opens eventvwr.msc to review system diagnostics and crash logs."; Icon=$UI.Admin },
    @{ Cmd="taskschd.msc";Name="Launch Task Scheduler";        Desc="Opens taskschd.msc to inspect automated Windows tasks."; Icon=$UI.Admin },
    @{ Cmd="wf.msc";      Name="Launch Advanced Firewall";     Desc="Opens wf.msc to configure inbound and outbound network filtering rules."; Icon=$UI.Shield },
    @{ Cmd="ms-settings:windowsupdate"; Name="Windows Update Settings"; Desc="Opens modern Windows 11 Windows Update settings."; Icon=$UI.Refresh },
    @{ Cmd="ms-settings:appsfeatures";  Name="Installed Apps Settings"; Desc="Opens modern Windows 11 Installed Apps & Features settings."; Icon=$UI.Apps },
    @{ Cmd="ms-settings:network-advancedsettings"; Name="Advanced Network Settings"; Desc="Opens modern Windows 11 Advanced Network settings."; Icon=$UI.Net },
    @{ Cmd="ms-settings:privacy";       Name="Privacy & Security Settings"; Desc="Opens modern Windows 11 Privacy & Security settings."; Icon=$UI.Privacy }
) | ForEach-Object {
    $q = $_
    $cmd = $q.Cmd; $name = $q.Name
    $qlCode = "Start-Process '$cmd'; Write-Log '$name opened.' 'Success'"
    New-TweakCard $P_Admin $q.Icon $q.Name "Quick Launcher" $q.Desc $qlCode
}

New-TweakCard $P_Admin $UI.Admin "Export Tweak Profile" "Profile Manager" "Exports all current toggle tweak configurations to a JSON profile on Desktop." {
    $desk = Get-UserDesktopPath
    $outPath = Join-Path $desk "AdminWorks_Profile_$((Get-Date).ToString('yyyyMMdd_HHmmss')).json"
    $profileData = @{}
    foreach ($card in $script:AllCards) {
        $toggle = $card.Panel.Controls | Where-Object { $_ -is [Win11ToggleSwitch] } | Select-Object -First 1
        if ($toggle -and $toggle.Tag.CheckAction) {
            $state = try { [bool](& $toggle.Tag.CheckAction) } catch { $false }
            $profileData[$card.Title] = $state
        }
    }
    $profileData | ConvertTo-Json -Depth 2 | Out-File -FilePath $outPath -Encoding UTF8
    Write-Log "Tweak profile successfully exported to: $outPath" "Success"
}

New-TweakCard $P_Admin $UI.Refresh "Import Tweak Profile" "Profile Manager" "Scans Desktop for AdminWorks_Profile_*.json and synchronizes toggle states." {
    $desk = Get-UserDesktopPath
    $files = Get-ChildItem -Path $desk -Filter "AdminWorks_Profile_*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if (-not $files -or $files.Count -eq 0) {
        Write-Log "No AdminWorks_Profile_*.json found on Desktop." "Warning"
        return
    }
    $targetFile = $files[0].FullName
    Write-Log "Importing latest profile: $($files[0].Name)..." "Exec"
    $json = Get-Content $targetFile -Raw | ConvertFrom-Json
    foreach ($prop in $json.PSObject.Properties) {
        $tTitle = $prop.Name
        $desiredActive = [bool]$prop.Value
        foreach ($tCard in $script:ToggleCards) {
            $cardObj = $script:AllCards | Where-Object { $_.Title -eq $tTitle } | Select-Object -First 1
            if ($cardObj) {
                $ctrl = $tCard.Control
                $curActive = $tCard.IsActive
                if ($curActive -ne $desiredActive) {
                    $code = if ($desiredActive) { $tCard.EnableCode } else { $tCard.DisableCode }
                    $tCard.IsActive = $desiredActive
                    Invoke-AdminWorksAction $code $ctrl { param($c) Update-ToggleStateVisual $c $desiredActive }
                    Write-Log "Applied profile: $tTitle -> $(if ($desiredActive) {'ENABLED'} else {'DISABLED'})" "Info"
                }
            }
        }
    }
    Write-Log "Profile import complete." "Success"
}

New-TweakCard $P_Admin $UI.Shield "Defender Quick Scan" "Antivirus" "Updates threat intelligence signatures and launches a Windows Defender scan." {
    Update-MpSignature | Out-Null; Start-MpScan -ScanType QuickScan | Out-Null
    Write-Log "Microsoft Defender Quick Scan complete." "Success"
}

foreach ($toggle in $script:ToggleCards) {
    if ($toggle.CheckAction) {
        try {
            $initialState = [bool](& $toggle.CheckAction)
            $toggle.IsActive = $initialState
            Update-ToggleStateVisual $toggle.Control $initialState
        } catch {}
    }
}

foreach ($k in $script:CategoryPanels.Keys) {
    $c = ($script:CategoryPanels[$k].Controls | Where-Object { ($_ -is [System.Windows.Forms.Panel] -or $_ -is [Win11CardPanel]) -and $_.Tag -ne "Banner" }).Count
    if ($script:SidebarItems[$k] -and $script:SidebarItems[$k].Badge) { $script:SidebarItems[$k].Badge.Text = "$c" }
}

$Form.ResumeLayout($false)
Select-Tab "Maint"
Update-ResponsiveLayout

$Form.Add_KeyDown({
    if ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::F) { [void]$SearchBox.Focus(); $SearchBox.SelectAll(); $_.SuppressKeyPress = $true }
    elseif ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::L) { $LogBox.Clear(); Write-Log "Console cleared via shortcut." "Info"; $_.SuppressKeyPress = $true }
    elseif ($_.Control -and ($_.KeyCode -eq [System.Windows.Forms.Keys]::Oemtilde -or $_.KeyCode -eq [System.Windows.Forms.Keys]::J)) { $BtnToggleDrawer.PerformClick(); $_.SuppressKeyPress = $true }
    elseif ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
        if ($SearchBox.Text -ne $SearchPlaceholder) { $SearchBox.Text = $SearchPlaceholder; $SearchBox.ForeColor = $script:Theme.TextSubtle; [void]$Form.Focus(); $_.SuppressKeyPress = $true }
    }
    elseif ($_.Control -and $_.KeyCode -ge [System.Windows.Forms.Keys]::D1 -and $_.KeyCode -le [System.Windows.Forms.Keys]::D9) {
        $tabIdx = [int]$_.KeyCode - [int][System.Windows.Forms.Keys]::D1
        if ($tabIdx -lt $TabList.Count) { Select-Tab $TabList[$tabIdx].Id; $_.SuppressKeyPress = $true }
    }
})

$TelemetryTimer = New-Object System.Windows.Forms.Timer -Property @{Interval = 2000; Enabled = $true}
$TelemetryTimer.Add_Tick({
    try {
        if ($script:CpuCounter) {
            $cpuVal = [math]::Round($script:CpuCounter.NextValue(), 0)
            $StatCPU.Text = "$cpuVal% Utilization"
            if ($StatCPU.Meter) {
                $cpuClamped = [math]::Max(0, [math]::Min(100, $cpuVal))
                $StatCPU.Meter.Value = $cpuClamped
                $StatCPU.Meter.FillColor = if ($cpuClamped -gt 85) { $script:Theme.Danger } elseif ($cpuClamped -gt 60) { $script:Theme.Warning } else { $script:Theme.Accent }
            }
        }
        $mem = New-Object NativeMethods+MEMORYSTATUSEX
        $mem.dwLength = [System.Runtime.InteropServices.Marshal]::SizeOf($mem)
        if ([NativeMethods]::GlobalMemoryStatusEx([ref]$mem)) {
            $totMemGB  = [math]::Round([double]$mem.ullTotalPhys / 1GB, 1)
            $freeMemGB = [math]::Round([double]$mem.ullAvailPhys / 1GB, 1)
            $usedMemGB = [math]::Round($totMemGB - $freeMemGB, 1)
            $StatRAM.Text = "$usedMemGB / $totMemGB GB"
            if ($StatRAM.Meter -and $totMemGB -gt 0) {
                $ramPct = [math]::Max(0, [math]::Min(100, [int](($usedMemGB / $totMemGB) * 100)))
                $StatRAM.Meter.Value = $ramPct
                $StatRAM.Meter.FillColor = if ($ramPct -gt 90) { $script:Theme.Danger } elseif ($ramPct -gt 75) { $script:Theme.Warning } else { $script:Theme.AccentGlow }
            }
        }
        $c = Get-PSDrive C -ErrorAction SilentlyContinue
        if ($c -and $c.Used -ne $null -and $c.Free -ne $null) {
            $freeGB = [math]::Round([double]$c.Free / 1GB, 1)
            $totGB  = [math]::Round(([double]$c.Used + [double]$c.Free) / 1GB, 1)
            $StatDisk.Text = "$freeGB GB Free ($totGB GB)"
            if ($StatDisk.Meter -and $totGB -gt 0) {
                $usedGB = [double]$c.Used / 1GB
                $diskPct = [math]::Max(0, [math]::Min(100, [int](($usedGB / $totGB) * 100)))
                $StatDisk.Meter.Value = $diskPct
                $StatDisk.Meter.FillColor = if ($diskPct -gt 90) { $script:Theme.Danger } else { $script:Theme.Success }
            }
        }
        $uptime = [TimeSpan]::FromMilliseconds([Environment]::TickCount64)
        $StatUp.Text = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
    } catch {}
})

$Form.Add_FormClosing({
    param($s, $e)
    if ($script:IsExecuting) {
        $res = [System.Windows.Forms.MessageBox]::Show(
            "A system task ($script:CurrentRunningTask) is currently running.`n`nClosing AdminWorks now may interrupt system changes. Exit anyway?",
            "Task in Progress",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($res -ne [System.Windows.Forms.DialogResult]::Yes) {
            $e.Cancel = $true
            return
        }
    }
    $TelemetryTimer.Stop(); $TelemetryTimer.Dispose()
    if ($script:CpuCounter) { $script:CpuCounter.Dispose() }
})

function Start-UpdateCheckAsync {
    $asyncPS = [powershell]::Create().AddScript({
        param($CurrentVer, $Repo)
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
            $headers = @{ "User-Agent" = "AdminWorks-AutoUpdater" }
            $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $headers -TimeoutSec 5 -ErrorAction Stop
            if ($latest -and $latest.tag_name) {
                $latestTag = [string]$latest.tag_name
                $cleanTagNum = ($latestTag -replace '^[^\d]*', '') -replace '[^\d\.]', ''
                $cleanCurNum = ($CurrentVer -replace '^[^\d]*', '') -replace '[^\d\.]', ''
                $vLatest = try { [version]$cleanTagNum } catch { [version]'0.0' }
                $vCur    = try { [version]$cleanCurNum } catch { [version]'0.0' }
                if ($vLatest -gt $vCur) {
                    return @{ Available = $true; Tag = $latestTag; Url = $latest.html_url }
                }
            }
        } catch {}
        return @{ Available = $false }
    }).AddArgument($script:AppVersion).AddArgument("KushagraKarira/AdminWorks")
    $asyncRS = [runspacefactory]::CreateRunspace()
    $asyncRS.ThreadOptions = "ReuseThread"
    $asyncRS.Open()
    $asyncPS.Runspace = $asyncRS
    $handle = $asyncPS.BeginInvoke()
    $checkTimer = New-Object System.Windows.Forms.Timer -Property @{Interval = 1000}
    $checkTimer.Tag = @{ PS = $asyncPS; RS = $asyncRS; Handle = $handle }
    $checkTimer.Add_Tick({
        $st = $this.Tag
        if ($st.Handle.IsCompleted) {
            try {
                $res = $st.PS.EndInvoke($st.Handle)
                if ($res -and $res[0].Available) {
                    $newTag = $res[0].Tag
                    if ($Form -and -not $Form.IsDisposed) {
                        [void]$Form.BeginInvoke([System.Action]{
                            $badgeText = if ($newTag.Length -le 7) { $newTag } else { "UPDATE" }
                            if ($BadgePro) { $BadgePro.Visible = $false }
                            $UpdateBadge.Text = $badgeText
                            $UpdateBadge.Visible = $true
                            if ($UpTip) { $UpTip.SetToolTip($UpdateBadge, "Update $newTag available on GitHub! Click to install.") }
                            Write-Log "New update available on GitHub: $newTag" "Success"
                        })
                    }
                }
            } catch {}
            try { $st.PS.Dispose() } catch {}
            try { $st.RS.Close(); $st.RS.Dispose() } catch {}
            $this.Stop(); $this.Dispose()
        }
    })
    $checkTimer.Start()
}

Write-Log "AdminWorks Pro Suite v$($script:AppVersion) loaded and ready." "Success"
Start-UpdateCheckAsync
try {
    [void]$Form.ShowDialog()
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "A runtime error occurred in AdminWorks:`n`n$($_.Exception.Message)`n`n$($_.ScriptStackTrace)",
        "AdminWorks Pro - Runtime Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
} finally {
    if ($Form -and -not $Form.IsDisposed) { $Form.Dispose() }
}

