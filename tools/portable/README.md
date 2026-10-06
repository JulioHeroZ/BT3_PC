# Pacote portátil para Windows

Este diretório contém as fontes do lançador e instalador e os scripts para gerar `Budokai Tenkaichi 3 Portable.zip`. Use dentro de um clone completo deste repositório, incluindo os submódulos. Não é um projeto independente.

## Pré-requisitos para compilar

- Windows 10/11 x64.
- Visual Studio Build Tools: C++, Clang para Windows, suporte MSBuild para ClangCL e Windows SDK.
- CMake, Git e Python 3.10 ou superior disponíveis no PATH. Ninja é recomendado.
- Sua ISO USA SLUS-21678. Outra região/revisão não é suportada.
- Internet para baixar as dependências na primeira compilação, e espaço para o build e os dados.

O ambiente C++ e o redistribuível são localizados pelo `vswhere`; nenhum caminho de usuário é necessário. O compilador C# do .NET Framework, presente no Windows, gera o instalador. Este fluxo usa o lançador Win32 simples e não precisa de Qt.

## Gerar o pacote

Na raiz do clone:

```powershell
git submodule update --init --recursive
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\portable\build-portable.ps1 -Iso "D:\Jogos\BT3-USA.iso" -Jobs 3
```

Sem `-Iso`, o script abre uma janela para selecionar a imagem. `-Python` permite informar outro executável Python. O diretório de saída padrão é `build/manual-portable`.

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

Versione as fontes e scripts deste diretório junto com o restante do port, suas licenças e referências dos submódulos. ISO, dados extraídos, código do jogo gerado, executáveis, DLLs, saves e ZIPs de saída ficam fora do Git. O ZIP produzido contém código nativo gerado a partir do jogo e não faz parte deste conjunto de fontes para publicação.

O fluxo foi verificado com os arquivos gerados da ISO USA na instalação de desenvolvimento. Uma compilação em máquina limpa ainda depende da instalação correta dos pré-requisitos e do download das dependências. Consulte também o README da raiz e a licença GPL-3.0 do projeto.
