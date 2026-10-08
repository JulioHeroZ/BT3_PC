# Port nativo: modo original, 60 fps e widescreen

Base: [z3xox/Tenkaichi3Decomp](https://github.com/z3xox/Tenkaichi3Decomp), v0.1.13,
commit `a7843dd4426350108c213ca11cc056269e7f4888`. A licença original está em `LICENSE`.

Em F1 > Video, **Frame rate** permite escolher **Original (30 fps)** ou **60 fps (visual interpolation)**.
A escolha é salva como `fps60` em `bt3_settings.txt`. O modo original é o padrão.
O seletor **Aspect ratio** oferece 4:3, 16:9 e outras proporções, com projeção e HUD apropriados.
O iniciador desta distribuição prepara 16:9 na primeira execução e respeita as escolhas posteriores.

O modo de 60 fps interpola as matrizes dos modelos entre quadros e apresenta a pose intermediária e a original.
A simulação mantém o ritmo original: não duplica atualizações de combate, áudio, timers, entrada ou RNG.
A correspondência usa a geometria, material, modo do shader e identificador do objeto, sem depender da ordem
dos modelos na lista. Modelos novos, mudanças de geometria e saltos grandes de posição usam a pose original.
Efeitos 2D e partes sem correspondência continuam no ritmo visual original. Portanto, esta opção não é uma
conversão da lógica do combate para 60 Hz. Exige mais trabalho da GPU que o modo original.

`BT3_FPS60=0/1` permite testar os dois modos; `BT3_FPS_DIAG=1` registra a taxa de apresentação e os quadros
que tiveram modelos interpolados. A lógica de rollback não contém esse histórico visual.

Compilação Windows: MSYS2 UCRT64, LLVM/Clang 22.1.8, GCC 16.2, SDL3 3.4.18 e bindings Python clang 21.1.7,
ou o container upstream em `port/release`. Os comandos `nm` e `gcc` usam arquivos de argumentos para evitar
o limite de tamanho de `CreateProcess` no Windows. As tabelas do jogo são compiladas vazias e preenchidas
apenas na execução a partir dos programas USA do usuário; nenhum recurso de disco integra esta publicação.

Validação local de 08/10/2026: compilação e link sem erros; luta automática sem janela concluída com saída 0;
Vulkan 2× e 16:9 no modo 60 concluído com saída 0, aproximadamente 59,9–60 apresentações/s e interpolação
ativa. Modo original com Vulkan e modo 60 com OpenGL também concluíram a luta com saída 0.
O seletor foi conferido visualmente no overlay. Os saves usados pelos testes ficam em um diretório isolado. O teste não cobre todos os personagens,
golpes, fases nem netplay. A implementação original do port e as limitações restantes estão em `docs/port`.
