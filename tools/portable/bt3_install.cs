using System;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Threading.Tasks;
using System.Windows.Forms;

class Install : Form {
    readonly Button choose = new Button { Text = "Selecionar ISO e instalar", Dock = DockStyle.Top, Height = 50 };
    readonly Label status = new Label { Text = "Selecione a ISO USA (SLUS-21678). Depois, abra Budokai Tenkaichi 3.exe.\nSerao necessarios aproximadamente 3 GB livres.", Dock = DockStyle.Fill, Padding = new Padding(12) };
    Install() {
        Text = "Instalar BT3 PC"; Width = 520; Height = 200;
        Controls.Add(status); Controls.Add(choose);
        choose.Click += async (sender, args) => {
            using (var picker = new OpenFileDialog { Filter = "ISO do jogo (*.iso)|*.iso", CheckFileExists = true }) {
                if (picker.ShowDialog() != DialogResult.OK) return;
                choose.Enabled = false; status.Text = "Verificando e extraindo os dados. Aguarde...";
                try { await Task.Run(() => Extract(picker.FileName)); status.Text = "Instalacao concluida. Abra Budokai Tenkaichi 3.exe.\nA ISO nao e mais necessaria para jogar."; }
                catch (Exception error) { status.Text = "Instalacao interrompida: " + error.Message; }
                finally { choose.Enabled = true; }
            }
        };
    }
    static void Tar(string iso, string staging, string members) {
        var info = new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "tar.exe"),
            "-xf \"" + iso + "\" -C \"" + staging + "\" " + members) {
            UseShellExecute = false, CreateNoWindow = true, RedirectStandardError = true
        };
        using (var process = Process.Start(info)) {
            string errors = process.StandardError.ReadToEnd(); process.WaitForExit();
            if (process.ExitCode != 0) throw new Exception("Falha na extracao: " + errors);
        }
    }
    static void Extract(string iso) {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string destination = Path.Combine(root, "data");
        if (Directory.Exists(destination)) throw new Exception("A pasta data ja existe. Preserve seus mods; use uma pasta nova para reinstalar.");
        if (new DriveInfo(Path.GetPathRoot(root)).AvailableFreeSpace < 3300000000L) throw new Exception("Espaco livre insuficiente.");
        string staging = Path.Combine(root, "instalacao-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(staging);
        try {
            Tar(iso, staging, "SLUS_216.78");
            string hash;
            using (var sha = SHA256.Create()) using (var file = File.OpenRead(Path.Combine(staging, "SLUS_216.78")))
                hash = BitConverter.ToString(sha.ComputeHash(file)).Replace("-", "").ToLowerInvariant();
            if (hash != "811188ba9b416500d921cd4d9514df0cbf42f3a41a99cf5aac5a3da37171bf99") throw new Exception("ISO incompativel. Use a versao USA SLUS-21678 suportada.");
            Tar(iso, staging, "BIN DATA IRX SYSTEM.CNF");
            foreach (string file in Directory.GetFiles(staging, "*", SearchOption.AllDirectories)) File.SetAttributes(file, FileAttributes.Normal);
            Directory.Move(staging, destination);
        } finally { if (Directory.Exists(staging)) Directory.Delete(staging, true); }
    }
    [STAThread] static int Main(string[] args) {
        if (args.Length == 2 && args[0] == "--install") {
            try { Extract(args[1]); return 0; }
            catch (Exception error) { File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "install-error.log"), error.ToString()); return 1; }
        }
        Application.EnableVisualStyles(); Application.Run(new Install()); return 0;
    }
}
