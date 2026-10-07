using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;

class Builder : Form {
    readonly Button build = new Button { Text = "Recompilar e instalar", Dock = DockStyle.Bottom, Height = 48 };
    readonly Button unblock = new Button { Text = "Desbloquear arquivos e tentar novamente", Dock = DockStyle.Bottom, Height = 42, Visible = false };
    readonly Label unblockNotice = new Label { Text = "Use o desbloqueio somente se confiar na origem do projeto. Ele remove a marca de download dos arquivos desta pasta.", Dock = DockStyle.Bottom, Height = 40, Visible = false, Padding = new Padding(8) };
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
    string logPath;
    DateTime lastOutput;
    volatile bool authorizationBlocked;
    readonly System.Windows.Forms.Timer startupWatch = new System.Windows.Forms.Timer { Interval = 1000 };
    Builder() {
        Text = "Dragon Ball Budokai Tenkaichi 3 - Instalacao (ferramentas automaticas v4)"; Width = 850; Height = 520;
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
        Controls.Add(log); Controls.Add(details); Controls.Add(unblockNotice); Controls.Add(unblock); Controls.Add(build); Controls.Add(progress); Controls.Add(percentage); Controls.Add(status);
        Controls.Add(folderRow); Controls.Add(new Label { Text = "Pasta de instalacao:", Dock = DockStyle.Top, Height = 24 }); Controls.Add(isoRow);
        details.CheckedChanged += (s, e) => log.Visible = details.Checked;
        startupWatch.Tick += (s, e) => {
            if (process == null || process.HasExited || (DateTime.UtcNow - lastOutput).TotalSeconds < 30) return;
            startupWatch.Stop();
            details.Checked = true;
            status.Text = "Sem novas mensagens. As ferramentas podem estar sendo instaladas em segundo plano.";
            Append("Nenhuma saida recebida do PowerShell por 30 segundos. Verifique pedidos de permissao ou bloqueios do Windows. Log: " + logPath);
        };
        isoBrowse.Click += (s, e) => SelectIso();
        browse.Click += (s, e) => {
            using (var picker = new FolderBrowserDialog { Description = "Escolha onde instalar o jogo" }) {
                if (picker.ShowDialog() == DialogResult.OK) destination.Text = Path.Combine(picker.SelectedPath, "Dragon Ball Budokai Tenkaichi 3");
            }
        };
        unblock.Click += async (sender, args) => {
            bool retry = false;
            unblock.Enabled = false; build.Enabled = false; browse.Enabled = false; isoBrowse.Enabled = false; destination.ReadOnly = true;
            status.Text = "Desbloqueando os arquivos do projeto...";
            try {
                Append("Removendo a marca de download somente dos arquivos da pasta do projeto.");
                process = new Process { StartInfo = GetUnblockStartInfo() };
                process.OutputDataReceived += (s, e) => Append(e.Data); process.ErrorDataReceived += (s, e) => Append(e.Data);
                process.Start(); process.StandardInput.Close(); process.BeginOutputReadLine(); process.BeginErrorReadLine();
                lastOutput = DateTime.UtcNow; startupWatch.Start();
                await Task.Run(() => process.WaitForExit());
                if (process.ExitCode != 0) throw new Exception("Nao foi possivel desbloquear os arquivos. Consulte os detalhes. Uma politica de seguranca pode exigir a ajuda do responsavel pelo computador.");
                Append("Arquivos desbloqueados. Iniciando uma nova tentativa de instalacao.");
                unblock.Visible = false; unblockNotice.Visible = false; retry = true;
            } catch (Exception error) {
                status.Text = "Desbloqueio interrompido. Consulte os detalhes.";
                details.Checked = true; Append(error.Message); MessageBox.Show(error.Message, "Desbloqueio interrompido");
            } finally {
                startupWatch.Stop(); if (process != null) { process.Dispose(); process = null; }
                unblock.Enabled = true; build.Enabled = true; browse.Enabled = true; isoBrowse.Enabled = true; destination.ReadOnly = false;
            }
            if (retry) build.PerformClick();
        };
        build.Click += async (sender, args) => {
            if (!File.Exists(iso.Text) && !SelectIso()) return;
            string script = Path.Combine(root, "tools", "portable", "build-portable.ps1");
            if (!File.Exists(script)) { MessageBox.Show("Mantenha este EXE na raiz do projeto completo."); return; }
            string install;
            try { install = Path.GetFullPath(destination.Text).TrimEnd(new char[] { '\\' }); }
            catch { MessageBox.Show("Escolha uma pasta de instalacao valida."); return; }
            string output = Path.Combine(root, "build", "pacote-" + DateTime.Now.ToString("yyyyMMdd-HHmmss"));
            try {
                script = PrepareEmbeddedTools();
                Directory.CreateDirectory(Path.GetDirectoryName(state)); File.WriteAllLines(state, new[] { iso.Text, install });
                Directory.CreateDirectory(output);
                logPath = Path.Combine(output, "recompilar.log");
                File.WriteAllText(logPath, "");
                log.Clear();
                authorizationBlocked = false;
                unblock.Visible = false; unblockNotice.Visible = false;
                build.Enabled = false; browse.Enabled = false; isoBrowse.Enabled = false; destination.ReadOnly = true;
                progress.Value = 0; percentage.Text = "Progresso estimado: 0%";
                status.Text = "Iniciando PowerShell e preparando as ferramentas...";
                Append("Iniciando a instalacao. Log: " + logPath);
                var info = new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe"),
                    "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"" + script + "\" -Iso \"" + iso.Text + "\" -OutDir \"" + output + "\" -InstallDir \"" + install + "\" -Jobs 3") {
                    WorkingDirectory = root, UseShellExecute = false, CreateNoWindow = true, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true
                };
                process = new Process { StartInfo = info };
                process.OutputDataReceived += (s, e) => Append(e.Data); process.ErrorDataReceived += (s, e) => Append(e.Data);
                process.Start(); process.StandardInput.Close(); process.BeginOutputReadLine(); process.BeginErrorReadLine();
                lastOutput = DateTime.UtcNow; startupWatch.Start();
                Append("PowerShell iniciado (PID " + process.Id + "). Aguardando preparacao das ferramentas.");
                await Task.Run(() => process.WaitForExit());
                if (process.ExitCode != 0 && authorizationBlocked) throw new Exception(GetAuthorizationHelp());
                if (process.ExitCode != 0) throw new Exception("A instalacao foi interrompida. Consulte os detalhes. Se as ferramentas pediram reinicio, reinicie e abra este programa novamente.");
                File.Delete(state); progress.Value = 100; percentage.Text = "Concluido: 100%";
                status.Text = "Jogo instalado. Use o atalho na area de trabalho.";
                MessageBox.Show("Instalado em:\n" + install + "\n\nUse o atalho na area de trabalho para jogar. A ISO nao e mais necessaria.", "Instalacao concluida");
            } catch (Exception error) { status.Text = "Instalacao interrompida. Consulte os detalhes."; unblock.Visible = authorizationBlocked; unblockNotice.Visible = authorizationBlocked; details.Checked = true; Append(error.Message); MessageBox.Show(error.Message, "Instalacao interrompida"); }
            finally { startupWatch.Stop(); if (process != null) { process.Dispose(); process = null; } build.Enabled = true; browse.Enabled = true; isoBrowse.Enabled = true; destination.ReadOnly = false; }
        };
        FormClosing += (sender, args) => { if (process != null && !process.HasExited) { args.Cancel = true; MessageBox.Show("Aguarde a instalacao terminar antes de fechar."); } };
    }
    string PrepareEmbeddedTools() {
        Assembly assembly = Assembly.GetExecutingAssembly();
        string folder = Path.Combine(root, "build", "installer-tools-" + assembly.ManifestModule.ModuleVersionId.ToString("N"));
        Directory.CreateDirectory(folder);
        foreach (string resource in assembly.GetManifestResourceNames()) {
            if (!resource.StartsWith("BT3Tools.", StringComparison.Ordinal)) continue;
            string name = resource.Substring("BT3Tools.".Length);
            if (Path.GetFileName(name) != name) throw new IOException("Nome invalido de ferramenta integrada.");
            string path = Path.Combine(folder, name);
            byte[] expected;
            using (Stream input = assembly.GetManifestResourceStream(resource))
            using (var buffer = new MemoryStream()) { input.CopyTo(buffer); expected = buffer.ToArray(); }
            if (File.Exists(path)) {
                byte[] actual = File.ReadAllBytes(path);
                if (Convert.ToBase64String(actual) != Convert.ToBase64String(expected)) throw new IOException("Ferramenta integrada alterada: " + path);
            } else {
                using (var output = new FileStream(path, FileMode.CreateNew, FileAccess.Write)) output.Write(expected, 0, expected.Length);
            }
        }
        string script = Path.Combine(folder, "build-portable.ps1");
        if (!File.Exists(script)) throw new IOException("EXE sem as ferramentas integradas. Use a versao completa do instalador.");
        return script;
    }
    bool SelectIso() {
        using (var picker = new OpenFileDialog { Filter = "ISO USA (*.iso)|*.iso", CheckFileExists = true }) {
            if (picker.ShowDialog() != DialogResult.OK) return false;
            iso.Text = picker.FileName; return true;
        }
    }
    void Append(string line) {
        if (line == null || IsDisposed) return;
        if (line.IndexOf("AuthorizationManager", StringComparison.OrdinalIgnoreCase) >= 0 ||
            line.IndexOf("PSSecurityException", StringComparison.OrdinalIgnoreCase) >= 0) authorizationBlocked = true;
        BeginInvoke((Action)(() => {
            lastOutput = DateTime.UtcNow;
            log.AppendText(line + "\r\n");
            if (logPath != null) {
                try { File.AppendAllText(logPath, line + Environment.NewLine); }
                catch (IOException error) { log.AppendText("Nao foi possivel gravar o log: " + error.Message + "\r\n"); }
                catch (UnauthorizedAccessException error) { log.AppendText("Nao foi possivel gravar o log: " + error.Message + "\r\n"); }
            }
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
    string GetAuthorizationHelp() {
        string command = "Get-ChildItem -LiteralPath '" + root.Replace("'", "''") + "' -Recurse -File | Unblock-File";
        return "O PowerShell bloqueou a execucao do script. Arquivos baixados da internet podem estar bloqueados.\r\n\r\n" +
            "Se voce confia na origem do projeto, feche esta mensagem e clique em Desbloquear arquivos e tentar novamente. O desbloqueio acontece em segundo plano e a instalacao sera repetida se ele terminar com sucesso.\r\n\r\n" +
            "Alternativa manual:\r\n" +
            "1. Abra o PowerShell pelo menu Iniciar (nao precisa executar como administrador).\r\n" +
            "2. Copie o comando abaixo dos detalhes tecnicos, cole no PowerShell e pressione Enter:\r\n\r\n" + command + "\r\n\r\n" +
            "3. Volte a esta janela e clique em Recompilar e instalar novamente.\r\n\r\n" +
            "Para um novo download: clique com o botao direito no ZIP, abra Propriedades, marque Desbloquear (se disponivel), aplique e extraia novamente em uma pasta nova.\r\n\r\n" +
            "Se o bloqueio persistir, pode existir uma politica de seguranca do Windows. Consulte o responsavel pelo computador e envie o recompilar.log para suporte.";
    }
    ProcessStartInfo GetUnblockStartInfo() {
        string script = "$ErrorActionPreference = 'Stop'; try { " +
            "function Unblock-Project([string]$folder) { " +
            "Get-ChildItem -LiteralPath $folder -Force -ErrorAction Stop | ForEach-Object { " +
            "if (($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) { " +
            "if ($_.PSIsContainer) { Unblock-Project $_.FullName } else { Unblock-File -LiteralPath $_.FullName -ErrorAction Stop } } } }; " +
            "Unblock-Project '" + root.Replace("'", "''") + "'; [Console]::WriteLine('Desbloqueio concluido.'); exit 0 " +
            "} catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }";
        return new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe"),
            "-NoLogo -NoProfile -NonInteractive -EncodedCommand " + Convert.ToBase64String(Encoding.Unicode.GetBytes(script))) {
            WorkingDirectory = root, UseShellExecute = false, CreateNoWindow = true,
            RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true
        };
    }
    void UpdateProgress(int value, string text) {
        if (value < progress.Value) return;
        progress.Value = Math.Max(progress.Value, Math.Min(100, Math.Max(0, value)));
        percentage.Text = "Progresso estimado: " + progress.Value + "%"; status.Text = text;
    }
    [STAThread] static void Main() { Application.EnableVisualStyles(); Application.Run(new Builder()); }
}
