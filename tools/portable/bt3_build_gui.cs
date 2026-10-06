using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

class Builder : Form {
    readonly Button build = new Button { Text = "Selecionar ISO e gerar pacote", Dock = DockStyle.Top, Height = 48 };
    readonly TextBox log = new TextBox { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, Dock = DockStyle.Fill };
    Process process;
    Builder() {
        Text = "Budokai Tenkaichi 3 - Recompilador"; Width = 860; Height = 540;
        Controls.Add(log); Controls.Add(build);
        log.Text = "Selecione sua ISO USA SLUS-21678. As ferramentas serao preparadas automaticamente.\r\nA primeira compilacao precisa de internet e pode solicitar permissao de administrador.\r\n";
        build.Click += async (sender, args) => {
            using (var picker = new OpenFileDialog { Filter = "ISO USA (*.iso)|*.iso", CheckFileExists = true }) {
                if (picker.ShowDialog() != DialogResult.OK) return;
                string root = AppDomain.CurrentDomain.BaseDirectory;
                string script = Path.Combine(root, "tools", "portable", "build-portable.ps1");
                if (!File.Exists(script)) { MessageBox.Show("Mantenha este EXE na raiz do clone completo do projeto."); return; }
                string output = Path.Combine(root, "build", "pacote-" + DateTime.Now.ToString("yyyyMMdd-HHmmss"));
                build.Enabled = false;
                try {
                    var info = new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe"),
                        "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\" -Iso \"" + picker.FileName + "\" -OutDir \"" + output + "\" -Jobs 3") {
                        WorkingDirectory = root, UseShellExecute = false, CreateNoWindow = true,
                        RedirectStandardOutput = true, RedirectStandardError = true
                    };
                    process = new Process { StartInfo = info };
                    process.OutputDataReceived += (s, e) => Append(e.Data);
                    process.ErrorDataReceived += (s, e) => Append(e.Data);
                    process.Start(); process.BeginOutputReadLine(); process.BeginErrorReadLine();
                    await Task.Run(() => process.WaitForExit());
                    if (process.ExitCode != 0) throw new Exception("A geracao falhou. Consulte as mensagens acima.");
                    Append("Pacote pronto: " + Path.Combine(output, "Budokai Tenkaichi 3 Portable.zip"));
                    MessageBox.Show("Pacote gerado em:\n" + output, "Concluido");
                } catch (Exception error) { Append(error.Message); MessageBox.Show(error.Message, "Erro"); }
                finally { if (process != null) { process.Dispose(); process = null; } build.Enabled = true; }
            }
        };
        FormClosing += (sender, args) => {
            if (process != null && !process.HasExited) { args.Cancel = true; MessageBox.Show("Aguarde a compilacao terminar antes de fechar."); }
        };
    }
    void Append(string line) { if (line != null && !IsDisposed) BeginInvoke((Action)(() => log.AppendText(line + "\r\n"))); }
    [STAThread] static void Main() { Application.EnableVisualStyles(); Application.Run(new Builder()); }
}
