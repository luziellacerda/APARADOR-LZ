using System;
using System.IO;
using System.Windows.Forms;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Reflection;
using System.Text;
using System.Threading;

[assembly: AssemblyTitle("Aparador de vídeos LZ Games")]
[assembly: AssemblyProduct("APARADOR DE VIDEOS LZ-GAMES")]
[assembly: AssemblyDescription("Painel local para compactar e recortar vídeos")]
[assembly: AssemblyVersion("1.5.0.0")]
[assembly: AssemblyFileVersion("1.5.0.0")]
[assembly: AssemblyInformationalVersion("1.5.0")]

internal static class Program {
    private static readonly string Root = AppDomain.CurrentDomain.BaseDirectory;
    private static readonly object LogLock = new object();
    private static bool Silent;

    [STAThread]
    static int Main(string[] commandLine) {
        AppDomain.CurrentDomain.UnhandledException += delegate(object sender, UnhandledExceptionEventArgs args) {
            WriteDiagnostic("Exceção não tratada; encerrando=" + args.IsTerminating,
                args.ExceptionObject == null ? "Sem objeto de exceção." : args.ExceptionObject.ToString());
        };

        try {
            // Propagate UI exceptions to the caller instead of the generic Continue dialog.
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.ThrowException);
            bool selfTest = false;
            string dataRoot = null;
            foreach (string arg in commandLine) if (arg == "--self-test") Silent = true;
            for (int i = 0; i < commandLine.Length; i++) {
                if (commandLine[i] == "--self-test") selfTest = true;
                else if (commandLine[i] == "--data-root" && i + 1 < commandLine.Length) dataRoot = Path.GetFullPath(commandLine[++i]);
                else throw new ArgumentException("Parâmetro desconhecido ou incompleto: " + commandLine[i]);
            }
            if (selfTest && dataRoot == null)
                dataRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "LZGames", "SelfTests", Guid.NewGuid().ToString("N"));
            string script;
            using (Stream resource = Assembly.GetExecutingAssembly().GetManifestResourceStream("LZGames.Backend.ps1")) {
                if (resource == null) throw new InvalidOperationException("O recurso interno do programa está ausente. Reinstale o aplicativo.");
                using (var reader = new StreamReader(resource, Encoding.UTF8, true)) script = reader.ReadToEnd();
            }
            using (Runspace runspace = RunspaceFactory.CreateRunspace()) {
                runspace.ApartmentState = ApartmentState.STA;
                runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                runspace.Open();
                using (PowerShell engine = PowerShell.Create()) {
                    engine.Runspace = runspace;
                    // Persist stream errors when they occur, even if a window is still open.
                    engine.Streams.Error.DataAdded += delegate(object sender, DataAddedEventArgs args) {
                        var records = (PSDataCollection<ErrorRecord>)sender;
                        WriteDiagnostic("Erro do PowerShell durante a execução", DescribeError(records[args.Index]));
                    };
                    engine.AddScript(script).AddParameter("RuntimeRoot", Root);
                    if (dataRoot != null) engine.AddParameter("DataRoot", dataRoot);
                    if (selfTest) engine.AddParameter("SelfTest", true);
                    engine.Invoke();
                    if (engine.HadErrors) {
                        var details = new StringBuilder();
                        foreach (ErrorRecord error in engine.Streams.Error)
                            details.AppendLine(DescribeError(error));
                        ShowFailure("O painel encontrou um erro e foi encerrado.",
                            WriteDiagnostic("A execução terminou com erros", details.ToString()));
                        return 1;
                    }
                }
            }
        } catch (Exception ex) {
            ShowFailure("Não foi possível continuar a execução.\n\n" + ex.Message,
                WriteDiagnostic("Falha de abertura ou execução", ex.ToString()));
            return 1;
        }
        return 0;
    }

    private static string DescribeError(ErrorRecord error) {
        var text = new StringBuilder();
        text.AppendLine(error.ToString());
        text.AppendLine("ID: " + error.FullyQualifiedErrorId);
        text.AppendLine("Categoria: " + error.CategoryInfo);
        if (error.Exception != null) text.AppendLine(error.Exception.ToString());
        if (error.InvocationInfo != null) text.AppendLine(error.InvocationInfo.PositionMessage);
        text.AppendLine("Pilha PowerShell: " + error.ScriptStackTrace);
        return text.ToString();
    }

    private static string WriteDiagnostic(string phase, string detail) {
        lock (LogLock) {
            var text = new StringBuilder();
            text.AppendLine("LZ Games 1.5.0 — diagnóstico local");
            text.AppendLine("Data: " + DateTimeOffset.Now.ToString("o"));
            text.AppendLine("Etapa: " + phase);
            text.AppendLine("Pasta: " + Root);
            text.AppendLine("Sistema: " + Environment.OSVersion);
            text.AppendLine("CLR: " + Environment.Version);
            text.AppendLine("Processo 64 bits: " + Environment.Is64BitProcess);
            text.AppendLine("PowerShell: " + typeof(PowerShell).Assembly.FullName);
            text.AppendLine(detail);
            string name = "lz-games-" + DateTime.UtcNow.ToString("yyyyMMdd-HHmmss-fff") + "-" + Guid.NewGuid().ToString("N") + ".log";
            string[] folders = {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "LZGames", "Logs"),
                Path.Combine(Path.GetTempPath(), "LZGames-Logs")
            };
            var failures = new StringBuilder();
            foreach (string folder in folders) {
                try {
                    Directory.CreateDirectory(folder);
                    string path = Path.Combine(folder, name);
                    File.WriteAllText(path, text.ToString(), Encoding.UTF8);
                    return path;
                } catch (Exception logError) {
                    failures.AppendLine(folder + ": " + logError.Message);
                }
            }
            return "Não foi possível gravar o diagnóstico.\n" + failures;
        }
    }

    private static void ShowFailure(string message, string diagnostic) {
        if (Silent) return;
        MessageBox.Show(message + "\n\nDiagnóstico:\n" + diagnostic,
            "LZ Games — erro de execução", MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}
