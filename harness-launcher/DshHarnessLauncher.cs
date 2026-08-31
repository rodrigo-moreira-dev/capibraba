// DeepSeek Harness Launcher
// 1) Inicia o servidor "dsh web" (sem abrir navegador sozinho).
// 2) Captura a URL autenticada (com token) do stdout.
// 3) Abre o Edge/Chrome em tela cheia nessa URL.
// 4) Mantem o servidor vivo enquanto o launcher estiver aberto.
// Compilar com: C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:exe /out:DshHarnessLauncher.exe DshHarnessLauncher.cs
using System;
using System.Diagnostics;
using System.IO;
using System.Net.Sockets;
using System.Text.RegularExpressions;
using System.Threading;

class DshHarnessLauncher
{
    const string Checkout = @"C:\workspace\Franklin's Project\deepseek-harness";
    const string NodeExe  = @"C:\nvm4w\nodejs\node.exe";
    const int    Port     = 3080;

    static readonly Regex UrlRegex = new Regex(@"dsh web:\s*(http\S+)", RegexOptions.Compiled);

    // Caminhos dos navegadores que suportam --start-fullscreen. Chrome primeiro
    // (preferência do usuário); Edge como fallback.
    static readonly string[] Browsers = new string[]
    {
        @"C:\Program Files\Google\Chrome\Application\chrome.exe",
        @"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        @"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        @"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    };

    static int Main()
    {
        Console.WriteLine("DeepSeek Harness Launcher");
        Console.WriteLine("=========================");
        Console.WriteLine("Checkout: " + Checkout);

        // 0) Se a porta ja esta ocupada, nao inicia um segundo servidor.
        if (IsPortOpen(Port))
        {
            Console.WriteLine();
            Console.WriteLine("O harness ja parece estar rodando na porta " + Port + ".");
            Console.WriteLine("Vou abrir a URL base em tela cheia. Se aparecer 'authentication',");
            Console.WriteLine("feche a instancia anterior e rode este launcher novamente.");
            string baseUrl = "http://127.0.0.1:" + Port + "/";
            OpenFullScreen(baseUrl);
            Console.WriteLine("Navegador aberto. Encerre esta janela para sair.");
            WaitForExitKey();
            return 0;
        }

        // 1) Inicia o servidor, capturando stdout/stderr.
        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = NodeExe;
        psi.Arguments = "--import tsx/esm apps/cli/src/bin.ts web --no-open --port " + Port;
        psi.WorkingDirectory = Checkout;
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.RedirectStandardOutput = true;
        psi.RedirectStandardError = true;

        Process server;
        try
        {
            server = Process.Start(psi);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Falha ao iniciar o harness: " + ex.Message);
            WaitForExitKey();
            return 1;
        }

        Console.WriteLine("Servidor iniciado (PID " + server.Id + "). Aguardando a URL com token...");
        Console.WriteLine();

        string foundUrl = null;

        // Leitura em background do stdout e stderr.
        Thread stdoutThread = new Thread(delegate ()
        {
            try
            {
                string line;
                while ((line = server.StandardOutput.ReadLine()) != null)
                {
                    Console.WriteLine(line);
                    Match m = UrlRegex.Match(line);
                    if (m.Success && foundUrl == null)
                    {
                        foundUrl = m.Groups[1].Value;
                    }
                }
            }
            catch { }
        });
        stdoutThread.IsBackground = true;
        stdoutThread.Start();

        Thread stderrThread = new Thread(delegate ()
        {
            try
            {
                string line;
                while ((line = server.StandardError.ReadLine()) != null)
                {
                    Console.WriteLine("[stderr] " + line);
                }
            }
            catch { }
        });
        stderrThread.IsBackground = true;
        stderrThread.Start();

        // 2) Aguarda a URL com token (timeout generoso para o primeiro boot).
        int attempts = 0;
        while (foundUrl == null && attempts < 120)
        {
            if (server.HasExited)
            {
                Console.WriteLine("O servidor encerrou antes de imprimir a URL (veja a saida acima).");
                WaitForExitKey();
                return 1;
            }
            Thread.Sleep(500);
            attempts++;
        }

        // 3) Abre o navegador em tela cheia.
        if (foundUrl != null)
        {
            Console.WriteLine();
            Console.WriteLine("URL encontrada: " + foundUrl);
            Console.WriteLine("Abrindo em tela cheia...");
            OpenFullScreen(foundUrl);
        }
        else
        {
            Console.WriteLine("Nao foi possivel detectar a URL com token a tempo.");
            Console.WriteLine("Abra manualmente a linha 'dsh web: http://...?token=...' impressa acima.");
        }

        // 4) Mantem o launcher vivo enquanto o servidor roda.
        Console.WriteLine();
        Console.WriteLine("Servidor em execucao. Encerre esta janela para parar o harness.");
        server.WaitForExit();
        Console.WriteLine("Servidor encerrado.");
        WaitForExitKey();
        return 0;
    }

    static bool IsPortOpen(int port)
    {
        try
        {
            using (TcpClient client = new TcpClient())
            {
                IAsyncResult ar = client.BeginConnect("127.0.0.1", port, null, null);
                bool ok = ar.AsyncWaitHandle.WaitOne(700);
                if (ok)
                {
                    client.EndConnect(ar);
                    return true;
                }
            }
        }
        catch { }
        return false;
    }

    static void OpenFullScreen(string url)
    {
        string browser = FindBrowser();
        if (browser != null)
        {
            StartBrowser(browser, url);
        }
        else
        {
            Console.WriteLine("Navegador com suporte a tela cheia nao encontrado; abrindo no padrao.");
            Process.Start(new ProcessStartInfo("cmd.exe", "/c start \"\" \"" + url + "\"")
            {
                UseShellExecute = false,
                CreateNoWindow = true,
            });
        }
    }

    static string FindBrowser()
    {
        foreach (string b in Browsers)
        {
            if (File.Exists(b)) return b;
        }
        return null;
    }

    static void StartBrowser(string browserPath, string url)
    {
        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = browserPath;
        psi.Arguments = "--new-window --start-fullscreen \"" + url + "\"";
        psi.UseShellExecute = true;
        try
        {
            Process.Start(psi);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Falha ao abrir o navegador: " + ex.Message);
        }
    }

    static void WaitForExitKey()
    {
        Console.WriteLine();
        Console.WriteLine("Pressione Enter para fechar...");
        try { Console.ReadLine(); } catch { }
    }
}
