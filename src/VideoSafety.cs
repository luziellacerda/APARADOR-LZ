using System;
using System.Collections.Concurrent;
using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32.SafeHandles;

namespace LZGames.Safety {
    public sealed class PathIdentity {
        public string Path { get; internal set; }
        public string Id { get; internal set; }
    }

    public static class Paths {
        [StructLayout(LayoutKind.Sequential)]
        private struct FileInformation {
            public uint Attributes;
            public System.Runtime.InteropServices.ComTypes.FILETIME CreationTime, AccessTime, WriteTime;
            public uint VolumeSerial, SizeHigh, SizeLow, LinkCount, IndexHigh, IndexLow;
        }
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        private static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr security, uint disposition, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError=true)]
        private static extern bool GetFileInformationByHandle(SafeFileHandle handle, out FileInformation information);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        private static extern uint GetFinalPathNameByHandle(SafeFileHandle handle, StringBuilder path, uint length, uint flags);

        public static PathIdentity Inspect(string path) {
            using (SafeFileHandle handle=CreateFile(System.IO.Path.GetFullPath(path),0,7,IntPtr.Zero,3,0x02000000,IntPtr.Zero)) {
                if(handle.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error(),"Não foi possível identificar o caminho: "+path);
                FileInformation info;
                if(!GetFileInformationByHandle(handle,out info)) throw new Win32Exception(Marshal.GetLastWin32Error());
                var buffer=new StringBuilder(32768);
                uint length=GetFinalPathNameByHandle(handle,buffer,(uint)buffer.Capacity,0);
                if(length==0 || length>=buffer.Capacity) throw new Win32Exception(Marshal.GetLastWin32Error());
                string resolved=buffer.ToString();
                if(resolved.StartsWith(@"\\?\UNC\",StringComparison.OrdinalIgnoreCase)) resolved=@"\\"+resolved.Substring(8);
                else if(resolved.StartsWith(@"\\?\",StringComparison.Ordinal)) resolved=resolved.Substring(4);
                return new PathIdentity { Path=resolved, Id=info.VolumeSerial.ToString("X8")+":"+info.IndexHigh.ToString("X8")+info.IndexLow.ToString("X8") };
            }
        }
        public static FileStream OpenReadLease(string path) {
            return new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.Read);
        }
        public static bool IsWithin(string root,string path) {
            string basePath=System.IO.Path.GetFullPath(root).TrimEnd('\\','/');
            string fullPath=System.IO.Path.GetFullPath(path).TrimEnd('\\','/');
            return String.Equals(basePath,fullPath,StringComparison.OrdinalIgnoreCase) || fullPath.StartsWith(basePath+System.IO.Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase);
        }
        public static string RelativePath(string root,string path) {
            string basePath=System.IO.Path.GetFullPath(root).TrimEnd('\\','/')+System.IO.Path.DirectorySeparatorChar;
            string fullPath=System.IO.Path.GetFullPath(path);
            if(!fullPath.StartsWith(basePath,StringComparison.OrdinalIgnoreCase))throw new IOException("O arquivo está fora da pasta de origem selecionada.");
            return fullPath.Substring(basePath.Length);
        }
        public static string EnsureSafeDirectory(string root,string relativeDirectory,bool create) {
            string physicalRoot=Inspect(root).Path;
            if(System.IO.Path.IsPathRooted(relativeDirectory ?? ""))throw new IOException("A subpasta de saída precisa ser relativa à pasta de resultados.");
            string current=physicalRoot;
            foreach(string segment in (relativeDirectory ?? "").Split(new char[]{'\\','/'},StringSplitOptions.RemoveEmptyEntries)) {
                if(segment=="." || segment=="..")throw new IOException("A subpasta de saída contém um caminho inválido.");
                string candidate=System.IO.Path.Combine(current,segment);
                if(!IsWithin(physicalRoot,candidate))throw new IOException("A subpasta de saída escaparia da pasta de resultados.");
                bool exists=false;FileAttributes attributes=0;
                try {attributes=File.GetAttributes(candidate);exists=true;} catch(FileNotFoundException) {} catch(DirectoryNotFoundException) {}
                if(exists) {
                    if((attributes&FileAttributes.ReparsePoint)!=0)throw new IOException("A saída contém um link ou junction em uma subpasta. Escolha uma pasta de resultados sem redirecionamentos.");
                    if((attributes&FileAttributes.Directory)==0)throw new IOException("Um arquivo ocupa o lugar de uma subpasta de saída.");
                } else if(create)Directory.CreateDirectory(candidate);
                else throw new DirectoryNotFoundException(candidate);
                if((File.GetAttributes(candidate)&FileAttributes.ReparsePoint)!=0)throw new IOException("A subpasta de saída passou a ser um link durante o processamento.");
                current=Inspect(candidate).Path;
                if(!IsWithin(physicalRoot,current))throw new IOException("A subpasta física está fora da pasta de resultados.");
            }
            return current;
        }
    }

    // No PowerShell or UI callbacks run on worker threads. Completion is published
    // only after stdout/stderr callbacks finish, including the final error lines.
    public sealed class MediaProcess : IDisposable {
        public readonly ConcurrentQueue<string> Output=new ConcurrentQueue<string>();
        public readonly ConcurrentQueue<string> Error=new ConcurrentQueue<string>();
        private readonly StringBuilder text=new StringBuilder();
        private readonly object gate=new object();
        private readonly ManualResetEvent finished=new ManualResetEvent(false);
        private int cancellation;
        private volatile bool complete;
        private int exitCode=-1;
        private long lastActivity;
        private double firstTimestamp=Double.PositiveInfinity, lastTimestamp=Double.NegativeInfinity, lastEnd=Double.NegativeInfinity;
        private int packets;
        public bool TimedOut { get; private set; }
        public bool Cancelled { get; private set; }
        public string Failure { get; private set; }
        public bool HasExited { get { return complete; } }
        public int ExitCode { get { return exitCode; } }
        public string Text { get { lock(gate) return text.ToString(); } }
        public double TimelineDuration { get { return lastEnd-firstTimestamp; } }
        public double LastPacketTimestamp { get { return lastTimestamp; } }
        public int PacketCount { get { return packets; } }

        public static MediaProcess Start(string executable,string arguments,int timeoutMilliseconds,bool timeline) {
            var result=new MediaProcess();
            Task.Factory.StartNew(()=>result.Run(executable,arguments,timeoutMilliseconds,timeline),CancellationToken.None,TaskCreationOptions.LongRunning,TaskScheduler.Default);
            return result;
        }
        private void Receive(string line,bool error,bool timeline) {
            try {
            if(line==null)return;
            Interlocked.Exchange(ref lastActivity,Stopwatch.GetTimestamp());
            if(error){Error.Enqueue(line);return;}
            if(timeline) {
                string[] values=line.Split(','); double pts,duration=0;
                if(values.Length>0 && Double.TryParse(values[0],NumberStyles.Float,CultureInfo.InvariantCulture,out pts)) {
                    if(values.Length>1) Double.TryParse(values[1],NumberStyles.Float,CultureInfo.InvariantCulture,out duration);
                    firstTimestamp=Math.Min(firstTimestamp,pts);lastTimestamp=Math.Max(lastTimestamp,pts);lastEnd=Math.Max(lastEnd,pts+Math.Max(0,duration));packets++;
                }
                return;
            }
            Output.Enqueue(line);
            lock(gate) { if(text.Length<2097152)text.AppendLine(line); }
            } catch(Exception e) { Failure="Falha ao ler a saída do processo: "+e.Message;Interlocked.Exchange(ref cancellation,2); }
        }
        private void Run(string executable,string arguments,int timeoutMilliseconds,bool timeline) {
            try {
                using(var process=new Process()) {
                    process.StartInfo=new ProcessStartInfo(executable,arguments) { UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true,StandardOutputEncoding=Encoding.UTF8,StandardErrorEncoding=Encoding.UTF8 };
                    process.OutputDataReceived+=(s,e)=>Receive(e.Data,false,timeline);
                    process.ErrorDataReceived+=(s,e)=>Receive(e.Data,true,timeline);
                    Interlocked.Exchange(ref lastActivity,Stopwatch.GetTimestamp());
                    if(Interlocked.CompareExchange(ref cancellation,0,0)!=0){Cancelled=Interlocked.CompareExchange(ref cancellation,0,0)==1;return;}
                    process.Start();process.BeginOutputReadLine();process.BeginErrorReadLine();
                    while(!process.WaitForExit(100)) {
                        bool cancel=Interlocked.CompareExchange(ref cancellation,0,0)!=0;
                        bool timeout=timeoutMilliseconds>0 && (Stopwatch.GetTimestamp()-Interlocked.Read(ref lastActivity))*1000.0/Stopwatch.Frequency>timeoutMilliseconds;
                        if(cancel || timeout) {
                            Cancelled=Interlocked.CompareExchange(ref cancellation,0,0)==1;TimedOut=timeout;
                            try {process.Kill();} catch(InvalidOperationException) {} catch(Exception e){Failure=e.Message;}
                            // Stay on the worker until the process really exits. The UI
                            // remains responsive and never removes a file still being used.
                        }
                    }
                    process.WaitForExit();exitCode=process.ExitCode;
                    if(Interlocked.CompareExchange(ref cancellation,0,0)==1)Cancelled=true;
                }
            } catch(Exception e){Failure=e.Message;}
            finally {finished.Set();complete=true;}
        }
        public void Kill(){Interlocked.Exchange(ref cancellation,1);}
        public void WaitForExit(){finished.WaitOne();}
        public bool WaitForExit(int milliseconds){return finished.WaitOne(milliseconds);}
        public void Dispose(){if(complete)finished.Dispose();else Kill();}
    }
}
