# Pacote portátil para Windows

Este diretório contém as fontes do lançador e instalador, os scripts e os programas auxiliares para gerar `Budokai Tenkaichi 3 Portable.zip`. Use dentro de um clone completo deste repositório. Não é um projeto independente.

## Pré-requisitos para compilar

- Windows 10/11 x64.
- Sua ISO USA SLUS-21678. Outra região/revisão não é suportada.
- Internet para baixar as dependências na primeira compilação, e espaço para o build e os dados.

Python, CMake, Ninja, MinGit e o recompiler genérico já estão em `programs/`, junto do instalador oficial do Build Tools. O manifesto registra origem, licença e SHA-256 de cada pacote. Os scripts verificam os hashes e extraem os programas automaticamente para `build/portable-programs/`; não é necessário instalá-los ou adicioná-los ao PATH manualmente.

Se faltar Visual Studio 2022 com C++/Clang, o instalador Microsoft é executado automaticamente com os componentes necessários e o Windows SDK. Autorize o UAC do Windows. A instalação pode pedir reinicialização; nesse caso, reinicie e execute novamente. A instalação do compilador/SDK e o primeiro download das bibliotecas ainda precisam de internet: este conjunto não é um instalador inteiramente offline.

O ambiente C++ e o redistribuível são localizados pelo `vswhere`; nenhum caminho de usuário é necessário. O compilador C# do .NET Framework, presente no Windows, gera os frontends. Este fluxo usa o lançador Win32 simples e não precisa de Qt.

## Gerar o pacote

Na raiz do clone, abra **`Recompilar-BT3.exe`**, selecione a ISO uma vez e confirme a pasta de instalação. O padrão é `C:\Program Files (x86)\Dragon Ball Budokai Tenkaichi 3`; é possível alterar o destino. O mesmo caminho da ISO é usado para compilar o executável e extrair todos os recursos. Ao terminar, o jogo está instalado e um atalho `Dragon Ball Budokai Tenkaichi 3` aparece na área de trabalho.

A interface mostra as etapas e um percentual **estimado** do processo. Durante a compilação, a atualização usa a contagem real de tarefas do Ninja. As tarefas não custam o mesmo tempo; o percentual não representa uma previsão exata da duração. Avisos completos ficam disponíveis em “Mostrar detalhes técnicos”.

Somente a cópia para uma pasta protegida é elevada pelo UAC. O jogo é aberto normalmente, sem administrador. Saves, configurações e logs de uma instalação ficam em `%LOCALAPPDATA%\Dragon Ball Budokai Tenkaichi 3`; os recursos originais ficam na pasta instalada. Os dados recebem permissão de edição para o usuário que instalou o jogo, sem liberar escrita nos executáveis e DLLs. Instalações existentes preservam dados modificados e configurações. Uma pasta contendo outros arquivos é recusada.

Cada execução pela interface recebe uma pasta de trabalho própria em `build/pacote-AAAAmmdd-HHMMSS/`. Se o SDK pedir reinício, a última ISO e destino são lembrados; abra a ferramenta novamente depois de reiniciar.

Para executar pelo PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\portable\build-portable.ps1 -Iso "D:\Jogos\BT3-USA.iso" -Jobs 3
```

Para também instalar pelo comando, acrescente `-InstallDir "D:\Jogos\Dragon Ball Budokai Tenkaichi 3"`. Nesse modo, os recursos são extraídos automaticamente da mesma ISO e o atalho é criado. Sem esse argumento, permanece disponível a geração do pacote portátil que instala recursos posteriormente; a interface gráfica usa a instalação integrada.

Sem `-Iso`, o script abre uma janela para selecionar a imagem. `-Python` permite substituir o Python incluído. O diretório de saída padrão da linha de comando é `build/manual-portable`. Os submódulos necessários são obtidos pelo pipeline existente. Para recompilar somente o frontend genérico, use `tools/portable/build-frontend.ps1`.

Para empacotar novamente um runner já compilado:

```powershell
.\tools\portable\build-portable.ps1 -SkipRecompile -OutDir "D:\Saida\novo-pacote"
```

A saída precisa ser nova: o script recusa sobrescrever instalações ou ZIPs existentes. Ele compila `Budokai Tenkaichi 3.exe` com o ícone do projeto, compila `Instalar-BT3.exe`, reúne o runner e as DLLs, verifica seus imports e cria o ZIP. Não copia dados extraídos ou saves pessoais.

## Testar em outro computador

1. Extraia todo o ZIP em uma pasta com permissão de escrita.
2. Abra `Instalar-BT3.exe` e selecione a ISO suportada. A validação usa o SHA-256 do ELF USA.
3. Aguarde a extração completa para `data/` (aproximadamente 3 GB).
4. Abra `Budokai Tenkaichi 3.exe`. Depois da instalação, a ISO não é necessária.

O computador de destino precisa de Windows 10/11 x64, .NET Framework 4.5+ e driver com OpenGL 3.3. Não precisa de ferramentas de compilação: o ZIP contém o runner gerado no computador que fez o build. Saves ficam em `savedata/`, logs em `logs/`. O instalador recusa sobrescrever `data/`, preservando instalações e mods.

## Conteúdo do Git

Versione as fontes e scripts deste diretório, os programas auxiliares de `programs/` e `Recompilar-BT3.exe` junto com o restante do port, suas licenças e referências dos submódulos. Esses programas são ferramentas genéricas. ISO, dados extraídos, código do jogo gerado, executáveis do jogo, saves e ZIPs de saída ficam fora do Git. O ZIP produzido contém código nativo gerado a partir do jogo e não faz parte deste conjunto de fontes para publicação.

Os programas incluídos foram executados e a preparação/geração do pacote foi verificada na instalação de desenvolvimento. A instalação integrada foi testada em uma pasta isolada, com extração da ISO, criação do atalho, abertura do jogo e configurações/logs no perfil do usuário. A instalação do SDK numa máquina limpa e a elevação para Program Files precisam de teste manual adicional; o compilador já estava instalado na máquina de validação. Consulte também o README da raiz e a licença GPL-3.0 do projeto. Cada programa de terceiros conserva sua própria licença, descrita no manifesto e incluída em seu pacote.
