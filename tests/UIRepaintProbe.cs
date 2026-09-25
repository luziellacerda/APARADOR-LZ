using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Reflection;
using System.IO;
using System.Security.Cryptography;
using System.Windows.Forms;

namespace LZGames.Tests {
    public sealed class RepaintResult {
        public string ControlType;
        public string Transition;
        public int DifferentPixels;
        public bool ResizeRedraw;
        public int InvalidatedRegions;
    }

    // Owned-control rendering only: no screen capture, mouse, keyboard, or user files.
    // DrawToBitmap always requests a complete paint and cannot expose stale artwork.
    // Keep the old overlapping canvas; repaint only managed invalidations and the
    // newly exposed resize strips, then compare with a complete fresh frame.
    public static class UIRepaintProbe {
        private static readonly BindingFlags Hidden = BindingFlags.Instance | BindingFlags.NonPublic;
        private static readonly MethodInfo StyleMethod = typeof(Control).GetMethod("GetStyle", Hidden);
        private static readonly MethodInfo BackgroundMethod = typeof(Control).GetMethod("OnPaintBackground", Hidden);
        private static readonly MethodInfo PaintMethod = typeof(Control).GetMethod("OnPaint", Hidden);
        private static void Paint(Control control, Bitmap target, Rectangle clip) {
            clip = Rectangle.Intersect(clip, new Rectangle(Point.Empty, target.Size));
            if (clip.Width <= 0 || clip.Height <= 0) return;
            // Separate layer prevents Graphics.Clear from clearing old pixels
            // outside the damage region even when a control ignores its clip.
            using (var layer = new Bitmap(target.Width, target.Height, PixelFormat.Format32bppArgb)) {
                using (var graphics = Graphics.FromImage(layer)) {
                    graphics.SetClip(clip);
                    using (var args = new PaintEventArgs(graphics, clip)) {
                        BackgroundMethod.Invoke(control, new object[] { args });
                        PaintMethod.Invoke(control, new object[] { args });
                    }
                }
                using (var graphics = Graphics.FromImage(target)) graphics.DrawImage(layer, clip, clip, GraphicsUnit.Pixel);
            }
        }
        private static int Difference(Bitmap first, Bitmap second) {
            int count = 0;
            for (int y = 0; y < first.Height; y++) for (int x = 0; x < first.Width; x++)
                if (first.GetPixel(x, y).ToArgb() != second.GetPixel(x, y).ToArgb()) count++;
            return count;
        }
        public static string SaveFrame(Control control, string path) {
            using (var frame = new Bitmap(control.Width, control.Height)) {
                Paint(control, frame, control.ClientRectangle);
                frame.Save(path, ImageFormat.Png);
                using (var stream = new MemoryStream()) using (var sha = SHA256.Create()) {
                    frame.Save(stream, ImageFormat.Png);
                    return BitConverter.ToString(sha.ComputeHash(stream.ToArray())).Replace("-", "");
                }
            }
        }
        public static RepaintResult Resize(Control control, Size before, Size after, string failurePrefix) {
            control.Size = before; control.CreateControl();
            using (var oldCanvas = new Bitmap(before.Width, before.Height)) {
                Paint(control, oldCanvas, new Rectangle(Point.Empty, before));
                var damaged = new List<Rectangle>();
                InvalidateEventHandler handler = delegate(object sender, InvalidateEventArgs args) { damaged.Add(args.InvalidRect); };
                control.Invalidated += handler;
                try { control.Size = after; } finally { control.Invalidated -= handler; }
                bool redraw = (bool)StyleMethod.Invoke(control, new object[] { ControlStyles.ResizeRedraw });
                if (redraw) damaged.Add(new Rectangle(Point.Empty, after));
                if (after.Width > before.Width) damaged.Add(new Rectangle(before.Width, 0, after.Width - before.Width, after.Height));
                if (after.Height > before.Height) damaged.Add(new Rectangle(0, before.Height, after.Width, after.Height - before.Height));
                using (var partial = new Bitmap(after.Width, after.Height)) using (var complete = new Bitmap(after.Width, after.Height)) {
                    using (var graphics = Graphics.FromImage(partial)) { graphics.Clear(control.BackColor); graphics.DrawImageUnscaled(oldCanvas, 0, 0); }
                    foreach (var clip in damaged) Paint(control, partial, clip);
                    Paint(control, complete, new Rectangle(Point.Empty, after));
                    int different = Difference(partial, complete);
                    if (different > 0 && !String.IsNullOrEmpty(failurePrefix)) {
                        partial.Save(failurePrefix + "-partial.png", ImageFormat.Png);
                        complete.Save(failurePrefix + "-complete.png", ImageFormat.Png);
                    }
                    return new RepaintResult { ControlType = control.GetType().Name,
                        Transition = before.Width + "x" + before.Height + " -> " + after.Width + "x" + after.Height,
                        DifferentPixels = different, ResizeRedraw = redraw, InvalidatedRegions = damaged.Count };
                }
            }
        }
    }
}
