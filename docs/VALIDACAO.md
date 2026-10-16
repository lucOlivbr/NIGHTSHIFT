# Validação da versão preparada para GitHub

## Verificações repetidas nesta preparação

Executadas em 16/10/2026, com Godot 4.7.2, sobre a versão principal, sem editar
os sistemas do jogo:

| Verificação | Resultado |
| --- | --- |
| Importação headless no editor | Aprovada, código de saída 0 |
| Abertura da cena principal por 120 frames | Aprovada, código de saída 0 |
| Percurso automatizado da missão no projeto | Vitória, guardas ativos, sem teletransportes nem objetivos forçados |
| Reinício após vitória e retorno ao menu no mesmo percurso | Aprovados |
| Percurso da build Windows já existente | Vitória, reinício e retorno ao menu aprovados novamente; sem recompilar |
| Cópia só com arquivos selecionados para o Git, sem cache ou experimentos | Importação, abertura e percurso completo aprovados, todos com saída 0 |

O encerramento automático após 120 frames emite `8 ObjectDB instances were
leaked at exit`, tanto na cópia original quanto na seleção limpa. Não houve
erro de parser ou script nos logs das verificações; o percurso completo e
o executável finalizaram sem esse aviso. O aviso não foi corrigido nesta
tarefa de documentação. A saída 0 não deve ser interpretada como ausência
de todos os avisos ou problemas possíveis.

O resultado do percurso desta preparação está em
[`evidence/project-playthrough.json`](evidence/project-playthrough.json).
O cenário continua sendo o principal: abertura da porta, coleta, alarme,
saída do armazém, montagem no skate e extração. O percurso conhecido dura
aproximadamente 98 segundos simulados; o modo acelerado não mede o tempo
real de uma primeira partida.

## Evidências preservadas da etapa de desenvolvimento anterior

Esses resultados são históricos da mesma base, não novas partidas manuais
nem suítes completas repetidas nesta tarefa:

| Evidência em `docs/evidence/` | Resultado registrado |
| --- | --- |
| `movement.json` | 29 verificações aprovadas; locomoção, salto, agachamento, câmera, colisão e skate, com guardas isolados |
| `guards.json` | 11 verificações aprovadas; patrulha, cobertura, detecção, perseguição, busca, captura e reinício em cenários preparados |
| `interface-audio.json` | 26 verificações aprovadas; menus, pausa, botões e reprodução dos WAVs |
| `native-clips.json` | Comparação de 128 fases dos oito clipes com a base nativa anterior; não avalia beleza das animações |
| `performance-street.json` e `performance-skate.json` | Amostras curtas na Intel Iris Xe, aproximadamente 60 FPS a 1280×720; não são mínimos ou benchmark completo |

As capturas foram inspecionadas visualmente. **Não houve uma partida manual
com teclado e mouse nesta preparação.** A naturalidade das animações,
cadência dos pés, dificuldade, conforto da câmera, diversão e duração de uma
primeira partida permanecem sujeitos a playtest. Testes históricos de versões
anteriores não foram tratados como aprovação automática da versão atual.

O resultado repetido no Windows está em `evidence/windows-playthrough.json`.
`evidence/windows-build.json` identifica a distribuição existente por SHA-256.
A build foi preservada e revalidada, sem nova exportação nesta tarefa.

## Reproduzir verificações básicas

Na raiz que contém `project.godot`, com o Godot Standard no PATH:

```powershell
godot --headless --editor --path . --quit
godot --headless --path . --quit-after 120
godot --headless --fixed-fps 60 --path . -- --self-test
```

O driver já existente é ativado exclusivamente pelo argumento `-- --self-test`.
Uma execução normal abre o menu. O resultado é escrito em
`docs/final_1_0/playthrough.json`, pasta mantida pelo `.gitkeep`; o JSON gerado
fica fora do Git. As ferramentas históricas locais de `tools/` não são
necessárias para essas três verificações e não acompanham a seleção pública.

Na pasta da build Windows:

```powershell
.\NIGHTSHIFT.console.exe --headless --fixed-fps 60 -- --self-test
```

Na build, o relatório é salvo em `user://final_playthrough.json`, na pasta
de dados do usuário do Godot para NIGHTSHIFT. O teste altera o estado da
partida durante a execução, não os assets ou a implementação do jogo.

## Avaliação humana ainda necessária

Abra `project.godot`, pressione F5 e jogue pelo menu. Confira caminhar, correr,
virar, saltar e agachar; observe os pés e as transições. Entre no Armazém 07,
segure E na porta e no pacote, saia durante o alarme, perca a perseguição e
alcance a extração de skate. Provoque uma captura e teste reinício e pausa.
Avalie também áudio, legibilidade, pontos de colisão e estabilidade de quadros.
Isso não foi marcado como validado apenas porque o percurso automático passou.
