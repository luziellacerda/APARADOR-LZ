using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Collections.Generic;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Windows.Forms;

namespace LZGames.UI {
    public static class Theme {
        public static readonly Color Background=Color.FromArgb(8,11,20), Surface=Color.FromArgb(15,21,35), Raised=Color.FromArgb(23,33,52), Border=Color.FromArgb(42,57,81), Text=Color.FromArgb(234,242,255), Muted=Color.FromArgb(152,171,199), Green=Color.FromArgb(60,225,222), Violet=Color.FromArgb(139,112,255);
        public static Font Font(float size, bool bold=false) { return new Font("Segoe UI",size,bold?FontStyle.Bold:FontStyle.Regular); }
        public static Color ParentColor(Control c) { for(Control p=c.Parent;p!=null;p=p.Parent)if(p.BackColor.A==255)return p.BackColor;return Surface; }
        public static GraphicsPath Round(Rectangle r,int radius) {
            int d=Math.Max(1,Math.Min(radius*2,Math.Min(r.Width,r.Height))); GraphicsPath p=new GraphicsPath();
            p.AddArc(r.X,r.Y,d,d,180,90);p.AddArc(r.Right-d,r.Y,d,d,270,90);
            p.AddArc(r.Right-d,r.Bottom-d,d,d,0,90);p.AddArc(r.X,r.Bottom-d,d,d,90,90);p.CloseFigure();return p;
        }
    }
    public class Card : Panel {
        public Color Accent=Theme.Green;
        public bool Highlight=false;
        public Card() { DoubleBuffered=true; BackColor=Theme.Surface; Padding=new Padding(18); }
        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e); e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
            if(Width<3||Height<3)return;
            using(var p=Theme.Round(new Rectangle(0,0,Width-1,Height-1),14)) {
                using(var pen=new Pen(Theme.Border)) e.Graphics.DrawPath(pen,p);
            }
            using(var pen=new Pen(Color.FromArgb(100,Accent),2))e.Graphics.DrawLine(pen,20,1,Math.Min(Width-20,Highlight?Width/2:64),1);
            if(Highlight) {
                using(var b=new SolidBrush(Color.FromArgb(18,Accent)))e.Graphics.FillEllipse(b,Width-88,12,64,64);
                using(var pen=new Pen(Color.FromArgb(125,Accent),1.5f)) {
                    e.Graphics.DrawEllipse(pen,Width-73,25,34,34);
                    e.Graphics.DrawLines(pen,new Point[]{new Point(Width-65,45),new Point(Width-58,38),new Point(Width-51,43),new Point(Width-44,33)});
                }
            }
        }
    }
    // Code-drawn artwork stays sharp at any DPI and adds no runtime downloads.
    public class StudioMark : Control {
        public StudioMark(){DoubleBuffered=true;BackColor=Theme.Background;}
        protected override void OnPaint(PaintEventArgs e){
            var g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;
            int s=Math.Min(Width,Height)-6;if(s<8)return;var r=new Rectangle((Width-s)/2,(Height-s)/2,s,s);
            using(var p=Theme.Round(r,14)){
                using(var b=new LinearGradientBrush(r,Color.FromArgb(28,68,81),Color.FromArgb(37,27,78),45))g.FillPath(b,p);
                using(var pen=new Pen(Theme.Green,1.3f))g.DrawPath(pen,p);
            }
            using(var f=Theme.Font(20,true))TextRenderer.DrawText(g,"LZ",f,r,Theme.Text,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);
        }
    }
    public class StudioHeader : Panel {
        public StudioHeader(){DoubleBuffered=true;BackColor=Theme.Background;}
        protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);if(Width<2||Height<2)return;
            using(var b=new LinearGradientBrush(ClientRectangle,Theme.Green,Theme.Violet,0f))e.Graphics.FillRectangle(b,0,Height-2,Width,2);
        }
    }
    public class EmptyLibrary : Panel {
        public EmptyLibrary(){DoubleBuffered=true;BackColor=Theme.Surface;}
        protected override void OnPaint(PaintEventArgs e){
            base.OnPaint(e);var g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;
            if(Height<210){
                int top=Math.Max(0,(Height-42)/2-28);
                using(var f=Theme.Font(13,true))TextRenderer.DrawText(g,"Seus vídeos. Mais leves.",f,new Rectangle(0,top,Width,28),Theme.Text,TextFormatFlags.HorizontalCenter|TextFormatFlags.EndEllipsis);
                using(var f=Theme.Font(9))TextRenderer.DrawText(g,"Comece escolhendo uma pasta abaixo.",f,new Rectangle(0,top+28,Width,22),Theme.Muted,TextFormatFlags.HorizontalCenter|TextFormatFlags.EndEllipsis);
                return;
            }
            int cx=Width/2,cy=Math.Max(46,Height/2-48);float scale=Math.Min(1f,Height/210f);
            var state=g.Save();g.TranslateTransform(cx,cy);g.ScaleTransform(scale,scale);
            for(int i=3;i>=1;i--)using(var b=new SolidBrush(Color.FromArgb(8,Theme.Green)))g.FillEllipse(b,-35-i*12,-35-i*12,70+i*24,70+i*24);
            using(var p=new Pen(Color.FromArgb(55,Theme.Violet))){g.DrawEllipse(p,-72,-45,144,90);g.DrawEllipse(p,-55,-60,110,120);}
            using(var p=Theme.Round(new Rectangle(-40,-30,80,60),12)){
                using(var b=new LinearGradientBrush(new Rectangle(-40,-30,80,60),Color.FromArgb(29,62,78),Color.FromArgb(39,31,77),45))g.FillPath(b,p);
                using(var pen=new Pen(Theme.Green,1.5f))g.DrawPath(pen,p);
            }
            using(var b=new SolidBrush(Theme.Green))g.FillPolygon(b,new Point[]{new Point(-8,-13),new Point(15,0),new Point(-8,13)});
            using(var b=new SolidBrush(Theme.Violet))g.FillEllipse(b,51,-34,7,7);
            g.Restore(state);
            using(var f=Theme.Font(16,true))TextRenderer.DrawText(g,"Seus vídeos. Mais leves.",f,new Rectangle(0,cy+(int)(65*scale),Width,30),Theme.Text,TextFormatFlags.HorizontalCenter|TextFormatFlags.EndEllipsis);
            using(var f=Theme.Font(9))TextRenderer.DrawText(g,"Adicione uma pasta. As subpastas vêm junto.",f,new Rectangle(0,cy+(int)(65*scale)+32,Width,22),Theme.Muted,TextFormatFlags.HorizontalCenter|TextFormatFlags.EndEllipsis);
        }
    }
    public class ActionButton : Button {
        public bool Primary=false, Selected=false;
        private bool hover;
        public ActionButton() { SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer,true); FlatStyle=FlatStyle.Flat;FlatAppearance.BorderSize=0;Cursor=Cursors.Hand;Font=Theme.Font(10,true);ForeColor=Theme.Text;BackColor=Theme.Surface;Margin=new Padding(4); }
        protected override void OnMouseEnter(EventArgs e){hover=true;Invalidate();base.OnMouseEnter(e);}
        protected override void OnMouseLeave(EventArgs e){hover=false;Invalidate();base.OnMouseLeave(e);}
        protected override void OnPaint(PaintEventArgs e){
            e.Graphics.Clear(Theme.ParentColor(this));e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
            Color fill=Primary?Theme.Green:(Selected?Color.FromArgb(24,57,71):(hover?Color.FromArgb(39,52,79):Theme.Raised));
            if(!Enabled)fill=Color.FromArgb(28,38,49);
            if(Width<3||Height<3)return;
            using(var path=Theme.Round(new Rectangle(1,1,Width-3,Height-3),9)){
                using(var brush=new LinearGradientBrush(ClientRectangle,fill,Primary&&Enabled?(hover?Color.FromArgb(131,236,255):Color.FromArgb(66,161,248)):fill,0f))e.Graphics.FillPath(brush,path);
                using(var pen=new Pen(Selected||hover?Theme.Green:(Primary?Color.FromArgb(131,242,255):Theme.Border)))e.Graphics.DrawPath(pen,path);
            }
            var flags=TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis;
            TextRenderer.DrawText(e.Graphics,Text,Font,ClientRectangle,!Enabled?Color.FromArgb(92,109,129):(Primary?Theme.Background:(Selected?Theme.Green:ForeColor)),flags);
            if(Focused)using(var path=Theme.Round(new Rectangle(4,4,Width-9,Height-9),6))using(var pen=new Pen(Primary?Theme.Background:Theme.Green)){e.Graphics.DrawPath(pen,path);}
        }
    }
    public class SelectBox : Control {
        public readonly List<string> Items=new List<string>();
        private readonly ContextMenuStrip menu;
        private int selected=-1;
        public event EventHandler SelectedIndexChanged;
        public int SelectedIndex { get{return selected;} set{if(value<0||value>=Items.Count)throw new ArgumentOutOfRangeException("value");if(selected!=value){selected=value;Text=SelectedItem??String.Empty;Invalidate();if(IsHandleCreated)AccessibilityNotifyClients(AccessibleEvents.ValueChange,-1);if(SelectedIndexChanged!=null)SelectedIndexChanged(this,EventArgs.Empty);}} }
        public string SelectedItem {get{return selected<0||selected>=Items.Count?null:Items[selected];}}
        public SelectBox(){
            Font=Theme.Font(10);BackColor=Theme.Raised;ForeColor=Theme.Text;Margin=new Padding(0,4,0,0);Dock=DockStyle.Fill;Cursor=Cursors.Hand;TabStop=true;AccessibleRole=AccessibleRole.ComboBox;
            AccessibleDescription="Use as setas para escolher; Enter, Espaço ou F4 para abrir as opções.";
            SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.Selectable,true);
            // Closed runs before WinForms has finished handling the clicked item. The
            // owner, not the Closed callback, owns and disposes this reusable menu.
            menu=new ContextMenuStrip{ShowImageMargin=false,BackColor=Theme.Raised,ForeColor=Theme.Text,AutoSize=false,Padding=new Padding(3)};
            menu.Opened+=(s,e)=>NotifyMenuState();
            menu.Closed+=(s,e)=>NotifyMenuState();
        }
        protected override void OnPaint(PaintEventArgs e){
            e.Graphics.Clear(Theme.ParentColor(this));e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
            using(var p=Theme.Round(new Rectangle(0,0,Width-1,Height-1),7)){using(var b=new SolidBrush(Theme.Raised))e.Graphics.FillPath(b,p);using(var pen=new Pen(Focused?Theme.Green:Theme.Border))e.Graphics.DrawPath(pen,p);}
            TextRenderer.DrawText(e.Graphics,Text,Font,new Rectangle(12,0,Math.Max(1,Width-40),Height),Enabled?Theme.Text:Theme.Muted,TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis|TextFormatFlags.NoPrefix);
            using(var p=new Pen(Theme.Muted,1.5f))e.Graphics.DrawLines(p,new Point[]{new Point(Width-22,Height/2-2),new Point(Width-18,Height/2+2),new Point(Width-14,Height/2-2)});
        }
        private void OpenMenu(){
            if(!Enabled||IsDisposed||Disposing||Items.Count==0||menu.Visible)return;
            Focus();
            while(menu.Items.Count>0){var old=menu.Items[0];menu.Items.RemoveAt(0);old.Dispose();}
            int itemHeight=Math.Max(36,Font.Height+16);
            menu.Font=Font;menu.Width=Math.Max(Width,80);menu.Height=Items.Count*itemHeight+6;
            for(int i=0;i<Items.Count;i++){
                int index=i;
                var item=new ToolStripMenuItem(Items[i]){AutoSize=false,Width=menu.Width-8,Height=itemHeight,ForeColor=i==selected?Theme.Green:Theme.Text,BackColor=Theme.Raised,Checked=i==selected,AccessibleName=Items[i]};
                item.Click+=(s,e)=>{if(!IsDisposed&&!Disposing&&index<Items.Count)SelectedIndex=index;};
                menu.Items.Add(item);
            }
            menu.Show(this,new Point(0,Height));
            if(selected>=0&&selected<menu.Items.Count)menu.Items[selected].Select();
        }
        private void NotifyMenuState(){if(!IsDisposed&&!Disposing){Invalidate();if(IsHandleCreated)AccessibilityNotifyClients(AccessibleEvents.StateChange,-1);}}
        private void ToggleMenu(){if(menu.Visible)menu.Close();else OpenMenu();}
        protected override void OnClick(EventArgs e){base.OnClick(e);OpenMenu();}
        protected override bool IsInputKey(Keys key){var k=key&Keys.KeyCode;if(k==Keys.Down||k==Keys.Up||k==Keys.Home||k==Keys.End)return true;return base.IsInputKey(key);}
        protected override void OnKeyDown(KeyEventArgs e){
            base.OnKeyDown(e);if(!Enabled||Items.Count==0)return;
            if(e.KeyCode==Keys.Space||e.KeyCode==Keys.Enter||e.KeyCode==Keys.F4||(e.Alt&&e.KeyCode==Keys.Down))ToggleMenu();
            else if(e.KeyCode==Keys.Escape&&menu.Visible)menu.Close();
            else if(e.KeyCode==Keys.Down)SelectedIndex=Math.Min(Items.Count-1,selected+1);
            else if(e.KeyCode==Keys.Up)SelectedIndex=Math.Max(0,selected-1);
            else if(e.KeyCode==Keys.Home)SelectedIndex=0;
            else if(e.KeyCode==Keys.End)SelectedIndex=Items.Count-1;
            else return;
            e.Handled=true;e.SuppressKeyPress=true;
        }
        protected override void OnEnabledChanged(EventArgs e){base.OnEnabledChanged(e);if(!Enabled&&menu!=null&&!menu.IsDisposed)menu.Close();Invalidate();}
        protected override void OnGotFocus(EventArgs e){base.OnGotFocus(e);Invalidate();}
        protected override void OnLostFocus(EventArgs e){base.OnLostFocus(e);Invalidate();}
        protected override void Dispose(bool disposing){if(disposing&&menu!=null)menu.Dispose();base.Dispose(disposing);}
        protected override AccessibleObject CreateAccessibilityInstance(){return new SelectBoxAccessibleObject(this);}
        private sealed class SelectBoxAccessibleObject : ControlAccessibleObject {
            private readonly SelectBox box;
            public SelectBoxAccessibleObject(SelectBox owner):base(owner){box=owner;}
            public override string Name{get{return box.AccessibleName??"Opções";}set{box.AccessibleName=value;}}
            public override string Value{get{return box.SelectedItem??String.Empty;}set{int index=box.Items.IndexOf(value);if(index>=0&&box.Enabled)box.SelectedIndex=index;}}
            public override AccessibleRole Role{get{return AccessibleRole.ComboBox;}}
            public override AccessibleStates State{get{return base.State|AccessibleStates.Focusable|(box.menu.Visible?AccessibleStates.Expanded:AccessibleStates.Collapsed);}}
            public override string DefaultAction{get{return box.menu.Visible?"Fechar opções":"Abrir opções";}}
            public override void DoDefaultAction(){if(!box.IsDisposed&&!box.Disposing&&box.Enabled)box.ToggleMenu();}
            public override int GetChildCount(){return box.menu.Visible?box.menu.Items.Count:0;}
            public override AccessibleObject GetChild(int index){return box.menu.Visible&&index>=0&&index<box.menu.Items.Count?box.menu.Items[index].AccessibilityObject:null;}
        }
    }
    public class Toggle : CheckBox {
        public Toggle(){AutoSize=false;Height=34;Font=Theme.Font(10);ForeColor=Theme.Text;Cursor=Cursors.Hand;SetStyle(ControlStyles.UserPaint|ControlStyles.OptimizedDoubleBuffer,true);}
        protected override void OnPaint(PaintEventArgs e){
            e.Graphics.Clear(Theme.ParentColor(this));e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
            using(var p=Theme.Round(new Rectangle(0,7,36,20),10))using(var b=new SolidBrush(Checked?Theme.Green:Theme.Border))e.Graphics.FillPath(b,p);
            using(var b=new SolidBrush(Checked?Theme.Background:Theme.Muted))e.Graphics.FillEllipse(b,Checked?19:3,10,14,14);
            TextRenderer.DrawText(e.Graphics,Text,Font,new Rectangle(47,0,Math.Max(1,Width-47),Height),Enabled?Theme.Text:Theme.Muted,TextFormatFlags.Left|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis);
            if(Focused)ControlPaint.DrawFocusRectangle(e.Graphics,new Rectangle(45,2,Math.Max(1,Width-47),Height-4));
        }
        protected override void OnCheckedChanged(EventArgs e){base.OnCheckedChanged(e);Invalidate();}
    }
    public class ProgressTrack : Control {
        private int value;
        private int shimmer;
        private readonly Timer animation;
        public int Value{get{return value;}set{this.value=Math.Max(0,Math.Min(100,value));animation.Enabled=this.value>0&&this.value<100&&Visible;Invalidate();}}
        public ProgressTrack(){Height=6;SetStyle(ControlStyles.UserPaint|ControlStyles.OptimizedDoubleBuffer,true);animation=new Timer{Interval=50};animation.Tick+=(s,e)=>{shimmer=(shimmer+5)%Math.Max(1,Width);Invalidate();};}
        protected override void OnVisibleChanged(EventArgs e){base.OnVisibleChanged(e);if(animation!=null)animation.Enabled=Visible&&value>0&&value<100;}
        protected override void Dispose(bool disposing){if(disposing)animation.Dispose();base.Dispose(disposing);}
        protected override void OnPaint(PaintEventArgs e){e.Graphics.Clear(Theme.Surface);e.Graphics.SmoothingMode=SmoothingMode.AntiAlias; if(Width<6||Height<4)return;
            using(var p=Theme.Round(new Rectangle(0,0,Width-1,Height-1),2))using(var b=new SolidBrush(Theme.Border))e.Graphics.FillPath(b,p);
            int w=(int)((Width-1)*value/100.0);if(w>4)using(var p=Theme.Round(new Rectangle(0,0,w,Height-1),2))using(var b=new LinearGradientBrush(new Rectangle(0,0,w,Height),Theme.Green,Theme.Violet,0f))e.Graphics.FillPath(b,p);
            if(value>0&&value<100&&shimmer<w)using(var b=new SolidBrush(Color.FromArgb(110,Color.White)))e.Graphics.FillRectangle(b,shimmer,1,Math.Min(18,w-shimmer),Math.Max(1,Height-3));
        }
    }
    public class PathDisplay : Control {
        public PathDisplay(){Font=Theme.Font(9);ForeColor=Theme.Text;BackColor=Theme.Raised;Dock=DockStyle.Fill;Margin=new Padding(8,0,2,0);SetStyle(ControlStyles.UserPaint|ControlStyles.OptimizedDoubleBuffer,true);}
        protected override void OnTextChanged(EventArgs e){base.OnTextChanged(e);Invalidate();}
        protected override void OnPaint(PaintEventArgs e){e.Graphics.Clear(BackColor);TextRenderer.DrawText(e.Graphics,Text,Font,ClientRectangle,ForeColor,TextFormatFlags.PathEllipsis|TextFormatFlags.VerticalCenter|TextFormatFlags.SingleLine|TextFormatFlags.NoPrefix);}
    }
    public class SecondsInput : NumericUpDown {
        private bool invalidEdit, formatting;
        public SecondsInput(){Minimum=0;Maximum=Int32.MaxValue;DecimalPlaces=3;Increment=1;ThousandsSeparator=false;}
        public bool TryReadSeconds(out decimal seconds,out string error){
            seconds=0;error=null;string entry=Text.Trim();
            if(!Regex.IsMatch(entry,@"^\d+(?:[.,]\d{1,3})?$")){
                error="Informe segundos, como 7,5 ou 7.5 (sem dois-pontos).";return false;
            }
            if(!Decimal.TryParse(entry.Replace(',','.'),NumberStyles.AllowDecimalPoint,CultureInfo.InvariantCulture,out seconds)||seconds<Minimum||seconds>Maximum){
                error="Informe segundos entre 0 e "+Maximum.ToString("0",CultureInfo.InvariantCulture)+".";return false;
            }
            return true;
        }
        public bool TryCommitSeconds(out decimal seconds,out string error){
            if(!TryReadSeconds(out seconds,out error)){invalidEdit=true;UserEdit=false;ForeColor=Color.FromArgb(255,140,125);return false;}
            invalidEdit=false;UserEdit=false;ForeColor=Theme.Text;Value=seconds;UpdateEditText();return true;
        }
        protected override void ValidateEditText(){decimal seconds;string error;TryCommitSeconds(out seconds,out error);}
        protected override void UpdateEditText(){
            if(invalidEdit||formatting)return;
            if(UserEdit){ValidateEditText();return;}
            formatting=true;
            try{ChangingText=true;Text=Value.ToString("0.###",CultureInfo.CurrentCulture);}
            finally{ChangingText=false;formatting=false;}
        }
        protected override void OnTextChanged(EventArgs e){if(!formatting){invalidEdit=false;ForeColor=Theme.Text;}base.OnTextChanged(e);}
        protected override void OnValueChanged(EventArgs e){invalidEdit=false;ForeColor=Theme.Text;base.OnValueChanged(e);}
    }
    public class Dashboard : Form {
        [DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr hwnd,int attribute,ref int value,int size);
        protected override void OnHandleCreated(EventArgs e){
            base.OnHandleCreated(e);
            // Unsupported Windows versions simply keep their native title bar.
            try{int dark=1;if(DwmSetWindowAttribute(Handle,20,ref dark,4)!=0)DwmSetWindowAttribute(Handle,19,ref dark,4);}catch(DllNotFoundException){}catch(EntryPointNotFoundException){}
        }
        public DataGridView grid;
        public Label filesCardValue,inputCardValue,savingCardValue,statusLabel;
        public PathDisplay inputPathBox,outputPathBox;
        public ActionButton startButton,cancelAction,refreshButton,inputBrowseButton,outputBrowseButton,openOutputButton,helpAction;
        public SelectBox presetBox,resolutionBox,fpsBox,audioBitrateBox;
        public Toggle audioCheck,trimCheck,overwriteCheck;
        public SecondsInput startNumeric,endNumeric;
        public Label trimSummaryLabel;
        public ProgressTrack fileProgress,overallProgress;
        public RichTextBox logBox;
        private Panel empty;
        private Label sourceSummary,profileHint;
        private Panel[] pages;
        private ActionButton[] tabs;
        private ActionButton[] navigation;
        private ToolTip tips=new ToolTip();
        private TableLayoutPanel rootLayout;
        private bool? compactLayout;
        public Dashboard(){
            Text="LZ GAMES  /  VIDEO STUDIO  /  1.4";BackColor=Theme.Background;ForeColor=Theme.Text;Font=Theme.Font(10);
            AutoScaleDimensions=new SizeF(96,96);AutoScaleMode=AutoScaleMode.Dpi;
            MinimumSize=new Size(960,560);Size=new Size(1260,740);StartPosition=FormStartPosition.CenterScreen;
            DoubleBuffered=true;
            var shell=Table(2,1);shell.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,82));shell.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));Controls.Add(shell);
            var rail=Table(1,3);rail.BackColor=Color.FromArgb(11,16,28);rail.RowStyles.Add(new RowStyle(SizeType.Absolute,82));rail.RowStyles.Add(new RowStyle(SizeType.Percent,100));rail.RowStyles.Add(new RowStyle(SizeType.Absolute,100));shell.Controls.Add(rail,0,0);
            var mark=new StudioMark{Dock=DockStyle.Fill,Margin=new Padding(10)};rail.Controls.Add(mark,0,0);
            var railItems=new TableLayoutPanel{Dock=DockStyle.Top,Height=247,ColumnCount=1,RowCount=3,Padding=new Padding(9,8,9,0),Margin=new Padding(0),BackColor=rail.BackColor};
            navigation=new ActionButton[3];string[] navNames={"01\nESTÚDIO","02\nRECORTE","03\nPASTAS"};
            for(int i=0;i<3;i++){int index=i;railItems.RowStyles.Add(new RowStyle(SizeType.Percent,33.333f));navigation[i]=Button(navNames[i],false);navigation[i].Font=Theme.Font(8,true);navigation[i].AccessibleName=navNames[i].Replace("\n"," ");navigation[i].Margin=new Padding(0,4,0,4);navigation[i].Click+=(s,e)=>SelectTab(index);railItems.Controls.Add(navigation[i],0,i);}
            rail.Controls.Add(railItems,0,1);
            var localBadge=Label("LOCAL\nOFFLINE\n\nv1.4",8,true,Theme.Muted);localBadge.TextAlign=ContentAlignment.MiddleCenter;rail.Controls.Add(localBadge,0,2);
            var root=Table(1,5);rootLayout=root;root.Padding=new Padding(22,16,22,20);root.BackColor=Theme.Background;
            root.RowStyles.Add(new RowStyle(SizeType.Absolute,68));root.RowStyles.Add(new RowStyle(SizeType.Absolute,12));
            root.RowStyles.Add(new RowStyle(SizeType.Absolute,86));root.RowStyles.Add(new RowStyle(SizeType.Absolute,18));root.RowStyles.Add(new RowStyle(SizeType.Percent,100));shell.Controls.Add(root,1,0);
            var headerFrame=new StudioHeader{Dock=DockStyle.Fill,Margin=new Padding(0),Padding=new Padding(0,0,0,9)};root.Controls.Add(headerFrame,0,0);
            var header=Table(2,1);header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));header.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,104));headerFrame.Controls.Add(header);
            var brand=Table(1,2);brand.RowStyles.Add(new RowStyle(SizeType.Absolute,34));brand.RowStyles.Add(new RowStyle(SizeType.Percent,100));
            brand.Controls.Add(Label("LZ GAMES / VIDEO STUDIO",21,true,Theme.Text),0,0);brand.Controls.Add(Label("APARADOR + COMPACTADOR    /    Seus arquivos. Sob seu controle.",9,false,Theme.Muted),0,1);header.Controls.Add(brand,0,0);
            helpAction=Button("?   Ajuda",false);helpAction.Margin=new Padding(8,8,0,8);header.Controls.Add(helpAction,1,0);
            var metrics=Table(3,1);for(int i=0;i<3;i++)metrics.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,33.333f));
            metrics.Controls.Add(Metric("VÍDEOS NA FILA","00",out filesCardValue),0,0);metrics.Controls.Add(Metric("TAMANHO ORIGINAL","0 MB",out inputCardValue),1,0);metrics.Controls.Add(Metric("REDUÇÃO TOTAL","—",out savingCardValue),2,0);savingCardValue.ForeColor=Theme.Green;
            root.Controls.Add(metrics,0,2);
            var body=Table(2,1);body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));body.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,350));root.Controls.Add(body,0,4);
            var library=new Card{Dock=DockStyle.Fill,Margin=new Padding(0,0,16,0),Padding=new Padding(16,10,16,12)};body.Controls.Add(library,0,0);
            var listLayout=Table(1,5);listLayout.RowStyles.Add(new RowStyle(SizeType.Absolute,40));listLayout.RowStyles.Add(new RowStyle(SizeType.Absolute,30));listLayout.RowStyles.Add(new RowStyle(SizeType.Percent,100));listLayout.RowStyles.Add(new RowStyle(SizeType.Absolute,70));listLayout.RowStyles.Add(new RowStyle(SizeType.Absolute,44));library.Controls.Add(listLayout);
            var listHead=Table(2,1);listHead.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));listHead.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,108));listHead.Controls.Add(Label("Biblioteca de vídeos",14,true,Theme.Text),0,0);refreshButton=Button("↻  Atualizar",false);refreshButton.Font=Theme.Font(9);listHead.Controls.Add(refreshButton,1,0);listLayout.Controls.Add(listHead,0,0);
            sourceSummary=Label("Pasta de origem",9,false,Theme.Muted);sourceSummary.AutoEllipsis=true;listLayout.Controls.Add(sourceSummary,0,1);
            var gridHost=new Panel{Dock=DockStyle.Fill,Margin=new Padding(0),BackColor=Theme.Surface};listLayout.Controls.Add(gridHost,0,2);
            grid=new DataGridView{Dock=DockStyle.Fill,ReadOnly=true,AllowUserToAddRows=false,AllowUserToDeleteRows=false,AllowUserToResizeRows=false,RowHeadersVisible=false,MultiSelect=false,StandardTab=true,SelectionMode=DataGridViewSelectionMode.FullRowSelect,BackgroundColor=Theme.Surface,BorderStyle=BorderStyle.None,CellBorderStyle=DataGridViewCellBorderStyle.SingleHorizontal,ColumnHeadersBorderStyle=DataGridViewHeaderBorderStyle.None,EnableHeadersVisualStyles=false,ColumnHeadersHeight=36,ColumnHeadersHeightSizeMode=DataGridViewColumnHeadersHeightSizeMode.DisableResizing,GridColor=Color.FromArgb(35,47,61)};
            grid.Font=Theme.Font(10);grid.RowTemplate.Height=40;
            grid.ColumnHeadersDefaultCellStyle.BackColor=Theme.Raised;grid.ColumnHeadersDefaultCellStyle.ForeColor=Theme.Muted;grid.ColumnHeadersDefaultCellStyle.Font=Theme.Font(9,true);grid.ColumnHeadersDefaultCellStyle.Padding=new Padding(8,0,0,0);
            grid.DefaultCellStyle.BackColor=Theme.Surface;grid.DefaultCellStyle.ForeColor=Theme.Text;grid.DefaultCellStyle.SelectionBackColor=Color.FromArgb(28,47,71);grid.DefaultCellStyle.SelectionForeColor=Theme.Text;grid.DefaultCellStyle.Padding=new Padding(8,0,4,0);
            grid.AlternatingRowsDefaultCellStyle.BackColor=Color.FromArgb(18,26,43);
            grid.Columns.Add("Status","STATUS");grid.Columns.Add("File","ARQUIVO");grid.Columns.Add("Input","ORIGINAL");grid.Columns.Add("Output","FINAL");grid.Columns.Add("Saving","REDUÇÃO");
            grid.Columns[0].Width=108;grid.Columns[1].AutoSizeMode=DataGridViewAutoSizeColumnMode.Fill;grid.Columns[1].MinimumWidth=125;grid.Columns[2].Width=88;grid.Columns[3].Width=88;grid.Columns[4].Width=86;
            foreach(DataGridViewColumn col in grid.Columns)col.SortMode=DataGridViewColumnSortMode.NotSortable;
            grid.CellPainting+=PaintStatus;
            gridHost.Controls.Add(grid);
            empty=new EmptyLibrary{Dock=DockStyle.Fill};var addFolder=Button("+   Adicionar pasta de vídeos",false);addFolder.Dock=DockStyle.Bottom;addFolder.Height=38;addFolder.Click+=(s,e)=>{SelectTab(2);if(inputBrowseButton.Enabled)inputBrowseButton.PerformClick();};empty.Controls.Add(addFolder);gridHost.Controls.Add(empty);empty.BringToFront();
            var progress=Table(1,4);progress.Padding=new Padding(0,7,0,0);progress.RowStyles.Add(new RowStyle(SizeType.Absolute,24));progress.RowStyles.Add(new RowStyle(SizeType.Absolute,8));progress.RowStyles.Add(new RowStyle(SizeType.Absolute,20));progress.RowStyles.Add(new RowStyle(SizeType.Absolute,5));
            statusLabel=Label("Pronto para começar",10,true,Theme.Muted);statusLabel.AutoEllipsis=true;progress.Controls.Add(statusLabel,0,0);fileProgress=new ProgressTrack{Dock=DockStyle.Fill,Margin=new Padding(0,0,0,2)};progress.Controls.Add(fileProgress,0,1);progress.Controls.Add(Label("PROGRESSO DO LOTE",8,false,Theme.Muted),0,2);overallProgress=new ProgressTrack{Dock=DockStyle.Fill,Margin=new Padding(0)};progress.Controls.Add(overallProgress,0,3);listLayout.Controls.Add(progress,0,3);
            logBox=new RichTextBox{Dock=DockStyle.Fill,ReadOnly=true,BorderStyle=BorderStyle.None,BackColor=Theme.Surface,ForeColor=Theme.Muted,Font=Theme.Font(9),Text="O resumo do processamento aparece aqui.",Margin=new Padding(0,8,0,0),TabStop=false};listLayout.Controls.Add(logBox,0,4);
            var settings=new Card{Dock=DockStyle.Fill,Padding=new Padding(16,10,16,12),Margin=new Padding(0),Accent=Theme.Violet};body.Controls.Add(settings,1,0);
            var settingsLayout=Table(1,4);settingsLayout.RowStyles.Add(new RowStyle(SizeType.Absolute,36));settingsLayout.RowStyles.Add(new RowStyle(SizeType.Absolute,40));settingsLayout.RowStyles.Add(new RowStyle(SizeType.Percent,100));settingsLayout.RowStyles.Add(new RowStyle(SizeType.Absolute,100));settings.Controls.Add(settingsLayout);
            settingsLayout.Controls.Add(Label("Laboratório de saída",14,true,Theme.Text),0,0);
            var tabStrip=Table(3,1);for(int i=0;i<3;i++)tabStrip.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,33.333f));tabs=new ActionButton[3];string[] tabNames={"Compactar","Recorte","Pastas"};
            var pageHost=new Panel{Dock=DockStyle.Fill,Margin=new Padding(0,6,0,4)};settingsLayout.Controls.Add(pageHost,0,2);pages=new Panel[3];
            for(int i=0;i<3;i++){int index=i;tabs[i]=Button(tabNames[i],false);tabs[i].Font=Theme.Font(9,true);tabs[i].Margin=new Padding(i==0?0:3,0,i==2?0:3,4);tabs[i].Click+=(s,e)=>SelectTab(index);tabStrip.Controls.Add(tabs[i],i,0);pages[i]=new Panel{Dock=DockStyle.Fill,AutoScroll=true,BackColor=Theme.Surface,Margin=new Padding(0)};pageHost.Controls.Add(pages[i]);}
            settingsLayout.Controls.Add(tabStrip,0,1);
            BuildCompression();BuildTrim();BuildFolders();SelectTab(0);
            var actions=Table(2,2);actions.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));actions.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));actions.RowStyles.Add(new RowStyle(SizeType.Absolute,52));actions.RowStyles.Add(new RowStyle(SizeType.Percent,100));
            startButton=Button("&Compactar vídeos",true);startButton.Font=Theme.Font(12,true);startButton.Margin=new Padding(0,0,0,8);actions.Controls.Add(startButton,0,0);actions.SetColumnSpan(startButton,2);
            cancelAction=Button("Cancelar",false);cancelAction.Enabled=false;cancelAction.Margin=new Padding(0,0,4,0);openOutputButton=Button("Abrir resultados",false);openOutputButton.Font=Theme.Font(9,true);openOutputButton.Margin=new Padding(4,0,0,0);actions.Controls.Add(cancelAction,0,1);actions.Controls.Add(openOutputButton,1,1);settingsLayout.Controls.Add(actions,0,3);
            tips.SetToolTip(startButton,"Iniciar a fila de vídeos (Alt+C)");tips.SetToolTip(grid,"Os vídeos originais são mantidos. O resultado é salvo na pasta de saída.");
            RefreshTrimSummary();UpdateQueueState(0);
            Shown+=(s,e)=>FitToWorkingArea(Screen.FromControl(this).WorkingArea);
            Resize+=(s,e)=>AdaptLayout();
            AdaptLayout();
        }
        public void FitToWorkingArea(Rectangle area){
            if(area.Width<=0||area.Height<=0)return;
            float scale=Math.Max(1f,CurrentAutoScaleDimensions.Height/96f);
            MinimumSize=new Size(Math.Min(area.Width,(int)Math.Ceiling(960*scale)),Math.Min(area.Height,(int)Math.Ceiling(560*scale)));
            if(WindowState==FormWindowState.Normal){
                Size=new Size(Math.Min(Width,area.Width),Math.Min(Height,area.Height));
                Location=new Point(Math.Max(area.Left,Math.Min(Left,area.Right-Width)),Math.Max(area.Top,Math.Min(Top,area.Bottom-Height)));
            }
            AdaptLayout();
        }
        private void AdaptLayout(){
            if(rootLayout==null||rootLayout.RowStyles.Count<5)return;
            float scale=Math.Max(1f,CurrentAutoScaleDimensions.Height/96f);
            bool compact=ClientSize.Height<620*scale;
            if(compactLayout.HasValue&&compactLayout.Value==compact)return;
            compactLayout=compact;
            rootLayout.SuspendLayout();
            rootLayout.Padding=compact?new Padding((int)(16*scale),(int)(12*scale),(int)(16*scale),(int)(12*scale)):new Padding((int)(24*scale),(int)(16*scale),(int)(24*scale),(int)(20*scale));
            rootLayout.RowStyles[0].Height=(compact?60:68)*scale;
            rootLayout.RowStyles[1].Height=(compact?8:12)*scale;
            rootLayout.RowStyles[2].Height=(compact?68:86)*scale;
            rootLayout.RowStyles[3].Height=(compact?12:18)*scale;
            rootLayout.ResumeLayout(true);
        }
        protected override void Dispose(bool disposing){if(disposing&&tips!=null){tips.Dispose();tips=null;}base.Dispose(disposing);}
        private static TableLayoutPanel Table(int cols,int rows){var t=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=cols,RowCount=rows,Margin=new Padding(0),Padding=new Padding(0),BackColor=Color.Transparent};if(rows==1)t.RowStyles.Add(new RowStyle(SizeType.Percent,100));if(cols==1)t.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));return t;}
        private static Label Label(string text,float size,bool bold,Color color){return new Label{Text=text,Font=Theme.Font(size,bold),ForeColor=color,Dock=DockStyle.Fill,TextAlign=ContentAlignment.MiddleLeft,Margin=new Padding(0),AutoSize=false};}
        private static ActionButton Button(string text,bool primary){return new ActionButton{Text=text,Primary=primary,Dock=DockStyle.Fill};}
        private static Card Metric(string caption,string value,out Label valueLabel){var c=new Card{Dock=DockStyle.Fill,Highlight=true,Accent=caption=="TAMANHO ORIGINAL"?Theme.Violet:Theme.Green,Padding=new Padding(16,7,64,7),Margin=new Padding(0,0,10,0)};var t=Table(1,2);t.RowStyles.Add(new RowStyle(SizeType.Absolute,22));t.RowStyles.Add(new RowStyle(SizeType.Percent,100));t.Controls.Add(Label(caption,8,true,Theme.Muted),0,0);valueLabel=Label(value,23,true,Theme.Text);valueLabel.AutoEllipsis=true;t.Controls.Add(valueLabel,0,1);c.Controls.Add(t);return c;}
        private void PaintStatus(object sender,DataGridViewCellPaintingEventArgs e){
            if(e.RowIndex<0||e.ColumnIndex!=0)return;
            e.PaintBackground(e.ClipBounds,true);string value=Convert.ToString(e.FormattedValue);
            Color ink=value.IndexOf("Erro",StringComparison.OrdinalIgnoreCase)>=0?Color.FromArgb(255,144,153):value.IndexOf("Pronto",StringComparison.OrdinalIgnoreCase)>=0?Theme.Muted:Theme.Green;
            var r=new Rectangle(e.CellBounds.X+7,e.CellBounds.Y+8,Math.Max(8,e.CellBounds.Width-14),Math.Max(8,e.CellBounds.Height-16));
            e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
            using(var p=Theme.Round(r,7))using(var b=new SolidBrush(Color.FromArgb(28,ink)))e.Graphics.FillPath(b,p);
            TextRenderer.DrawText(e.Graphics,value,e.CellStyle.Font,r,ink,TextFormatFlags.VerticalCenter|TextFormatFlags.HorizontalCenter|TextFormatFlags.EndEllipsis|TextFormatFlags.NoPrefix);e.Handled=true;
        }
        private static SelectBox Select(params string[] items){var b=new SelectBox();b.Items.AddRange(items);b.SelectedIndex=0;return b;}
        private static Panel Field(string caption,Control control){control.AccessibleName=caption;var p=new Panel{Dock=DockStyle.Fill,Margin=new Padding(0),BackColor=Theme.Surface};var t=Table(1,2);t.RowStyles.Add(new RowStyle(SizeType.Absolute,22));t.RowStyles.Add(new RowStyle(SizeType.Absolute,38));t.Controls.Add(Label(caption,9,false,Theme.Muted),0,0);control.Dock=DockStyle.Fill;t.Controls.Add(control,0,1);p.Controls.Add(t);return p;}
        private static TableLayoutPanel Page(Panel parent,params int[] heights){var t=Table(1,heights.Length);t.Dock=DockStyle.Top;t.Height=0;foreach(int h in heights){t.RowStyles.Add(new RowStyle(SizeType.Absolute,h));t.Height+=h;}parent.Controls.Add(t);return t;}
        private void BuildCompression(){
            var t=Page(pages[0],64,64,40,34,44);
            presetBox=Select("Ultra compacto · H.265","Equilibrado · H.265","Alta qualidade · H.265","Compatível · H.264");presetBox.SelectedIndex=1;t.Controls.Add(Field("Qualidade da imagem",presetBox),0,0);
            var pair=Table(2,1);pair.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,52));pair.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,48));resolutionBox=Select("Original","1080p","720p","480p");resolutionBox.SelectedIndex=2;fpsBox=Select("Original","60 FPS","30 FPS","24 FPS");fpsBox.SelectedIndex=2;var f=Field("Resolução máxima",resolutionBox);f.Margin=new Padding(0,0,8,0);pair.Controls.Add(f,0,0);pair.Controls.Add(Field("Fluidez máxima",fpsBox),1,0);t.Controls.Add(pair,0,1);
            audioCheck=new Toggle{Text="Manter o som do vídeo",Checked=true,Dock=DockStyle.Fill,Margin=new Padding(0,4,0,0)};t.Controls.Add(audioCheck,0,2);
            var audioRow=Table(2,1);audioRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));audioRow.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,110));audioRow.Controls.Add(Label("Qualidade do áudio",9,false,Theme.Muted),0,0);audioBitrateBox=Select("64k","96k","128k","192k");audioBitrateBox.AccessibleName="Qualidade do áudio";audioBitrateBox.SelectedIndex=2;audioRow.Controls.Add(audioBitrateBox,1,0);t.Controls.Add(audioRow,0,3);
            profileHint=Label("Boa qualidade visual e arquivo menor.\nO tamanho final depende do vídeo original.",9,false,Theme.Muted);profileHint.Margin=new Padding(0,10,0,0);t.Controls.Add(profileHint,0,4);
            presetBox.SelectedIndexChanged+=(s,e)=>{string[] hints={"Prioriza arquivos pequenos.\nPode reduzir detalhes da imagem.","Boa qualidade visual e arquivo menor.\nO tamanho final depende do vídeo original.","Preserva mais detalhes da imagem.\nDemora mais e produz arquivos maiores.","Funciona em mais aparelhos e players.\nPode ficar maior que a opção H.265."};profileHint.Text=hints[presetBox.SelectedIndex];};
        }
        private void BuildTrim(){
            var t=Page(pages[1],40,40,64,42,58);
            var info=Label("Digite livremente o início e o fim.\nOs valores são em segundos.",10,false,Theme.Muted);t.Controls.Add(info,0,0);
            trimCheck=new Toggle{Text="Recortar um trecho",Checked=false,Dock=DockStyle.Fill};t.Controls.Add(trimCheck,0,1);
            var pair=Table(2,1);pair.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));pair.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));startNumeric=Number(7);endNumeric=Number(22);var start=Field("Começar em (s)",startNumeric);start.Margin=new Padding(0,0,10,0);pair.Controls.Add(start,0,0);pair.Controls.Add(Field("Terminar em (s)",endNumeric),1,0);t.Controls.Add(pair,0,2);
            startNumeric.Enabled=false;endNumeric.Enabled=false;t.Controls.Add(Label("7 → 22 salva 15 s. Para refazer arquivos,\native Substituir na aba Pastas.",9,false,Theme.Muted),0,3);
            trimSummaryLabel=Label("Vídeo inteiro • recorte desligado",10,true,Theme.Muted);t.Controls.Add(trimSummaryLabel,0,4);
            trimCheck.CheckedChanged+=(s,e)=>RefreshTrimSummary();
            trimCheck.EnabledChanged+=(s,e)=>RefreshTrimSummary();
            startNumeric.TextChanged+=(s,e)=>RefreshTrimSummary();endNumeric.TextChanged+=(s,e)=>RefreshTrimSummary();
            startNumeric.ValueChanged+=(s,e)=>RefreshTrimSummary();endNumeric.ValueChanged+=(s,e)=>RefreshTrimSummary();
        }
        private static SecondsInput Number(int value){return new SecondsInput{Value=value,Font=Theme.Font(12),ForeColor=Theme.Text,BackColor=Theme.Raised,BorderStyle=BorderStyle.FixedSingle,Dock=DockStyle.Fill,Margin=new Padding(0,4,0,0)};}
        private bool ReadTrimRange(bool commit,out decimal start,out decimal end,out string error){
            start=0;end=0;error=null;
            if(!trimCheck.Checked)return true;
            string detail;
            if(!(commit?startNumeric.TryCommitSeconds(out start,out detail):startNumeric.TryReadSeconds(out start,out detail))){error="Início: "+detail;return false;}
            if(!(commit?endNumeric.TryCommitSeconds(out end,out detail):endNumeric.TryReadSeconds(out end,out detail))){error="Fim: "+detail;return false;}
            if(end<=start){error="O fim precisa ser maior que o início. Exemplo: 7 → 22.";return false;}
            return true;
        }
        public bool TryGetTrimRange(out decimal start,out decimal end,out string error){return ReadTrimRange(true,out start,out end,out error);}
        public void RefreshTrimSummary(){
            if(trimSummaryLabel==null||startNumeric==null||endNumeric==null)return;
            startNumeric.Enabled=trimCheck.Checked&&trimCheck.Enabled;endNumeric.Enabled=trimCheck.Checked&&trimCheck.Enabled;
            if(startButton!=null){startButton.Text=trimCheck.Checked?"&Recortar vídeos":"&Compactar vídeos";tips.SetToolTip(startButton,trimCheck.Checked?"Iniciar o recorte da fila (Alt+R)":"Iniciar a fila de vídeos (Alt+C)");}
            decimal start,end;string error;
            if(!trimCheck.Checked){trimSummaryLabel.Text="Vídeo inteiro • recorte desligado";trimSummaryLabel.ForeColor=Theme.Muted;}
            else if(ReadTrimRange(false,out start,out end,out error)){
                trimSummaryLabel.Text=String.Format(CultureInfo.CurrentCulture,"Trecho: {0:0.###} s → {1:0.###} s • {2:0.###} s",start,end,end-start);trimSummaryLabel.ForeColor=Theme.Green;
            }else{trimSummaryLabel.Text=error;trimSummaryLabel.ForeColor=Color.FromArgb(255,140,125);}
        }
        private void BuildFolders(){
            var t=Page(pages[2],70,70,44,60);
            inputPathBox=PathBox();outputPathBox=PathBox();inputBrowseButton=Button("Escolher",false);outputBrowseButton=Button("Escolher",false);
            t.Controls.Add(FolderRow("Vídeos de origem",inputPathBox,inputBrowseButton),0,0);t.Controls.Add(FolderRow("Salvar resultados em",outputPathBox,outputBrowseButton),0,1);
            overwriteCheck=new Toggle{Text="Substituir resultados",Checked=false,Dock=DockStyle.Fill};t.Controls.Add(overwriteCheck,0,2);
            t.Controls.Add(Label("Inclui subpastas; os resultados mantêm\na mesma organização. Originais preservados.\nPara refazer, ative Substituir resultados.",9,false,Theme.Muted),0,3);
            inputPathBox.TextChanged+=(s,e)=>{sourceSummary.Text="ORIGEM  /  "+inputPathBox.Text;tips.SetToolTip(sourceSummary,inputPathBox.Text);tips.SetToolTip(inputPathBox,inputPathBox.Text);};
            outputPathBox.TextChanged+=(s,e)=>tips.SetToolTip(outputPathBox,outputPathBox.Text);
        }
        private static PathDisplay PathBox(){return new PathDisplay();}
        private static Panel FolderRow(string caption,Control path,ActionButton browse){var p=new Panel{Dock=DockStyle.Fill,Margin=new Padding(0)};var t=Table(1,2);t.RowStyles.Add(new RowStyle(SizeType.Absolute,24));t.RowStyles.Add(new RowStyle(SizeType.Absolute,40));t.Controls.Add(Label(caption,10,true,Theme.Text),0,0);var row=Table(2,1);row.BackColor=Theme.Raised;row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,82));row.Controls.Add(path,0,0);browse.Font=Theme.Font(9);browse.Margin=new Padding(2);row.Controls.Add(browse,1,0);t.Controls.Add(row,0,1);p.Controls.Add(t);return p;}
        public void SelectTab(int index){if(index<0||index>=3)throw new ArgumentOutOfRangeException("index");for(int i=0;i<3;i++){pages[i].Visible=i==index;tabs[i].Selected=i==index;tabs[i].Invalidate();navigation[i].Selected=i==index;navigation[i].Invalidate();}pages[index].BringToFront();}
        public void UpdateQueueState(int count){empty.Visible=count==0;grid.Visible=count>0;filesCardValue.Text=count.ToString("00");}
    }
}
