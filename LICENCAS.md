# Recursos, créditos e alcance das licenças

Verificação para preparação do repositório: **16/10/2026**. As licenças dos
recursos de terceiros foram confrontadas com os avisos locais e as páginas
dos autores. Não foi atribuída uma licença única ao jogo inteiro.

## Recursos de terceiros incluídos

| Recurso / arquivos | Autor e fonte oficial | Licença e evidência |
| --- | --- | --- |
| Prédios, ruas, faixas e texturas `assets/Building_*`, `Street_*`, `Decal_*`, `T_*` | Quaternius — [Downtown City MegaKit](https://quaternius.com/packs/downtowncitymegakit.html), edição Standard | CC0 1.0, identificada na página do autor e nos créditos do projeto |
| Rig nativo e clipes de `refined_city.glb` e `nightshift_final.glb`; biblioteca de salto do jogador legado | Quaternius — [Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html), edição Standard | CC0 1.0; aviso original em `assets/characters/LICENSE_NATIVE.txt`; adaptações deste projeto |
| `nightshift_runner.glb`, originais em `assets/characters/source/`, cabeça/cabelo reaproveitados no protagonista | Quaternius — [Ultimate Modular Men Pack](https://quaternius.com/packs/ultimatemodularcharacters.html); [Hoodie](https://poly.pizza/m/gKLBoRsyKe) e [Casual](https://poly.pizza/m/kZ3DmIoGip) | CC0 1.0; `assets/characters/LICENSE.txt` e `character_manifest.json` registram origem e hashes |
| `assets/skate/skateboard_kenney.glb` e colormap; curvas `skate_motion_kenney.*` preservadas para o jogador legado | Kenney — [Mini Skate](https://kenney.nl/assets/mini-skate) | CC0 1.0; `assets/skate/LICENSE.txt`, `skate_manifest.json` e `skate_motion_manifest.json` |

A [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)
permite reutilização e redistribuição desses recursos, inclusive adaptados.
Os créditos foram mantidos mesmo quando a atribuição é opcional. Os originais
dos dois personagens são preservados para rastreabilidade; a pasta `source/`
contém `.gdignore` e não é importada para o jogo.

Os manifestos e alguns avisos antigos citam ferramentas e pesquisas locais.
Essas referências documentam a preparação histórica; tais arquivos não são
dependências da execução nem acompanham o repositório público. O protagonista
principal utiliza o rig nativo e uma postura estática de skate. As descrições
procedurais do aviso legado não descrevem sua animação atual.

## Áudio original

Conforme a declaração preexistente em `CREDITS.txt`, os WAVs produzidos para
NIGHTSHIFT são disponibilizados sob **CC0 1.0**. Não utilizam samples externos
ou músicas comerciais:

- `assets/audio/nightshift_noir.wav`: trilha instrumental trip-hop/noir.
- `assets/audio/rain_loop.wav` e `city_night_loop.wav`: ambientes sintetizados.
- `assets/audio/actions/`: `alarm`, `door`, `mount`, `noticed`, `parcel`,
  `wheels` e `win`, efeitos sintetizados offline.

Os três loops têm metadados e hashes em `assets/audio/audio_manifest.json`.
Os geradores permanecem localmente em `tools/`, fora da seleção pública;
os WAVs prontos estão incluídos e dispensam geração durante o jogo.

## Engine e ferramentas

O **Godot Engine** é distribuído sob MIT. O aviso está em
[GODOT_LICENSE.txt](GODOT_LICENSE.txt). Os avisos de seus componentes, incluindo
as fontes padrão da interface, estão em
[GODOT_THIRD_PARTY_NOTICES.txt](GODOT_THIRD_PARTY_NOTICES.txt), obtidos do engine
utilizado na build. Consulte também a [licença oficial do Godot](https://godotengine.org/license/).
Esses avisos devem acompanhar a distribuição Windows.

O Blender foi uma ferramenta de produção; o software não é redistribuído
neste repositório. Não foi incluído material de Skate 3 ou EA skate.

## Código e elementos autorais do NIGHTSHIFT

Lucas ainda não definiu uma licença geral para o código, a identidade visual
e os elementos autorais do jogo, como roupas adaptadas, bolsa, textos,
sinalização e composição da fase. Esta preparação **não concede uma licença
nova** para esses elementos. Publicar o repositório não equivale a disponibilizar
todo o projeto sob CC0 ou MIT. Uma futura escolha de licença precisa respeitar
as licenças independentes dos recursos acima.

## Material fora da publicação

`proofs/`, pesquisas de mocap CMU, arquivos de laboratório, ZIPs de fornecedores,
backups e fontes Blender experimentais não integram a seleção Git. Não foi
presumida licença de redistribuição para esses materiais. Eles continuam
preservados localmente. A auditoria acima abrange os assets da versão principal
selecionados para o repositório, não todos os experimentos.
