using System;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;

class Builder : Form {
    readonly Button build = new Button { Text = "Recompilar e instalar", Dock = DockStyle.Bottom, Height = 48 };
    readonly TextBox log = new TextBox { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, Dock = DockStyle.Fill, Visible = false };
    readonly TextBox iso = new TextBox { Dock = DockStyle.Fill, ReadOnly = true };
    readonly TextBox destination = new TextBox { Dock = DockStyle.Fill };
    readonly Label status = new Label { Text = "Selecione a ISO USA para comecar.", Dock = DockStyle.Top, Height = 45, Padding = new Padding(8) };
    readonly ProgressBar progress = new ProgressBar { Dock = DockStyle.Top, Height = 25 };
    readonly Label percentage = new Label { Text = "Progresso estimado: 0%", Dock = DockStyle.Top, Height = 24 };
    readonly CheckBox details = new CheckBox { Text = "Mostrar detalhes tecnicos", Dock = DockStyle.Bottom, Height = 28 };
    Process process;
    readonly string root = AppDomain.CurrentDomain.BaseDirectory;
    readonly string state;
    Builder() {
        Text = "Dragon Ball Budokai Tenkaichi 3 - Instalacao"; Width = 850; Height = 520;
        state = Path.Combine(root, "build", "ultima-instalacao.txt");
        string programFiles = Environment.GetEnvironmentVariable("ProgramFiles(x86)") ?? Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        destination.Text = Path.Combine(programFiles, "Dragon Ball Budokai Tenkaichi 3");
        if (File.Exists(state)) {
            string[] saved = File.ReadAllLines(state);
            if (saved.Length >= 2 && File.Exists(saved[0])) { iso.Text = saved[0]; destination.Text = saved[1]; }
        }
        var isoRow = new Panel { Dock = DockStyle.Top, Height = 38 };
        var isoBrowse = new Button { Text = "Selecionar ISO", Dock = DockStyle.Right, Width = 130 };
        isoRow.Controls.Add(iso); isoRow.Controls.Add(isoBrowse);
        var folderRow = new Panel { Dock = DockStyle.Top, Height = 38 };
        var browse = new Button { Text = "Alterar pasta", Dock = DockStyle.Right, Width = 130 };
        folderRow.Controls.Add(destination); folderRow.Controls.Add(browse);
        Controls.Add(log); Controls.Add(details); Controls.Add(build); Controls.Add(progress); Controls.Add(percentage); Controls.Add(status);
        Controls.Add(folderRow); Controls.Add(new Label { Text = "Pasta de instalacao:", Dock = DockStyle.Top, Height = 24 }); Controls.Add(isoRow);
        details.CheckedChanged += (s, e) => log.Visible = details.Checked;
        isoBrowse.Click += (s, e) => SelectIso();
        browse.Click += (s, e) => {
            using (var picker = new FolderBrowserDialog { Description = "Escolha onde instalar o jogo" }) {
                if (picker.ShowDialog() == DialogResult.OK) destination.Text = Path.Combine(picker.SelectedPath, "Dragon Ball Budokai Tenkaichi 3");
            }
        };
        build.Click += async (sender, args) => {
            if (!File.Exists(iso.Text) && !SelectIso()) return;
            string script = Path.Combine(root, "tools", "portable", "build-portable.ps1");
            if (!File.Exists(script)) { MessageBox.Show("Mantenha este EXE na raiz do projeto completo."); return; }
            string install;
            try { install = Path.GetFullPath(destination.Text).TrimEnd('\\'); }
            catch { MessageBox.Show("Escolha uma pasta de instalacao valida."); return; }
            string output = Path.Combine(root, "build", "pacote-" + DateTime.Now.ToString("yyyyMMdd-HHmmss"));
            Directory.CreateDirectory(Path.GetDirectoryName(state)); File.WriteAllLines(state, new[] { iso.Text, install });
            build.Enabled = false; browse.Enabled = false; isoBrowse.Enabled = false; destination.ReadOnly = true; progress.Value = 0;
            try {
                var info = new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe"),
                    "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\" -Iso \"" + iso.Text + "\" -OutDir \"" + output + "\" -InstallDir \"" + install + "\" -Jobs 3") {
                    WorkingDirectory = root, UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true
                };
                process = new Process { StartInfo = info };
                process.OutputDataReceived += (s, e) => Append(e.Data); process.ErrorDataReceived += (s, e) => Append(e.Data);
                process.Start(); process.BeginOutputReadLine(); process.BeginErrorReadLine();
                await Task.Run(() => process.WaitForExit());
                if (process.ExitCode != 0) throw new Exception("A instalacao foi interrompida. Consulte os detalhes. Se as ferramentas pediram reinicio, reinicie e abra este programa novamente.");
                File.Delete(state); progress.Value = 100; percentage.Text = "Concluido: 100%";
                status.Text = "Jogo instalado. Use o atalho na area de trabalho.";
                MessageBox.Show("Instalado em:\n" + install + "\n\nUse o atalho na area de trabalho para jogar. A ISO nao e mais necessaria.", "Instalacao concluida");
            } catch (Exception error) { details.Checked = true; Append(error.Message); MessageBox.Show(error.Message, "Instalacao interrompida"); }
            finally { if (process != null) { process.Dispose(); process = null; } build.Enabled = true; browse.Enabled = true; isoBrowse.Enabled = true; destination.ReadOnly = false; }
        };
        FormClosing += (sender, args) => { if (process != null && !process.HasExited) { args.Cancel = true; MessageBox.Show("Aguarde a instalacao terminar antes de fechar."); } };
    }
    bool SelectIso() {
        using (var picker = new OpenFileDialog { Filter = "ISO USA (*.iso)|*.iso", CheckFileExists = true }) {
            if (picker.ShowDialog() != DialogResult.OK) return false;
            iso.Text = picker.FileName; return true;
        }
    }
    void Append(string line) {
        if (line == null || IsDisposed) return;
        BeginInvoke((Action)(() => {
            log.AppendText(line + "\r\n");
            if (line.StartsWith("BT3_PROGRESS|")) {
                string[] fields = line.Split('|'); int value;
                if (fields.Length >= 3 && int.TryParse(fields[1], out value)) UpdateProgress(value, fields[2]);
            } else {
                Match tasks = Regex.Match(line, @"^\[(\d+)/(\d+)\]");
                if (tasks.Success) {
                    int done = int.Parse(tasks.Groups[1].Value), total = int.Parse(tasks.Groups[2].Value);
                    if (total > 8) UpdateProgress(15 + 70 * done / total, "Compilando o executavel: " + done + " de " + total + " tarefas");
                }
            }
        }));
    }
    void UpdateProgress(int value, string text) {
        if (value < progress.Value) return;
        progress.Value = Math.Max(progress.Value, Math.Min(100, Math.Max(0, value)));
        percentage.Text = "Progresso estimado: " + progress.Value + "%"; status.Text = text;
    }
    [STAThread] static void Main() { Application.EnableVisualStyles(); Application.Run(new Builder()); }
}
