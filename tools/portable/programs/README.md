# Programas incluídos

Os seis arquivos ZIP deste diretório contêm programas reais para Windows x64, e não apenas links ou scripts:

| Pacote | Conteúdo |
| --- | --- |
| Python | Interpretador e biblioteca padrão, distribuição embutida oficial |
| CMake | Executáveis e módulos da versão usada na validação |
| Ninja | Executor do build |
| MinGit | Git portátil oficial para obter dependências e submódulos |
| PS2Recomp | `ps2_recomp.exe` genérico compilado das fontes do projeto, com seu CRT |
| VS Build Tools | Bootstrap oficial Microsoft para instalar C++, ClangCL e Windows SDK |

`manifest.json` contém as versões, origens, licenças e hashes SHA-256. Os pacotes conservam suas licenças e notices. O recompiler é genérico: não inclui a ISO, recursos ou código recompilado do BT3. Suas fontes estão em `ps2xRecomp/` e as referências das bibliotecas estão no CMake do projeto.

O bootstrap Microsoft baixa e instala os componentes necessários; ele não contém o SDK completo. As bibliotecas C/C++ do projeto também são obtidas pelo CMake na primeira compilação. Portanto, ainda é necessária internet na preparação inicial.

Os programas são extraídos automaticamente para `build/portable-programs/` e usados somente no ambiente do processo de build. Não é necessário modificar o PATH global do Windows.
