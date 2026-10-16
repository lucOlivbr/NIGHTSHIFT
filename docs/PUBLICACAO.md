# Preparação para publicação

A raiz do repositório é a pasta que contém `project.godot`. Esta preparação
é local: não autoriza nem realiza push, criação de repositório remoto ou release.
Não havia Git ou remoto configurado. Foi iniciado um repositório local na
branch `main`, com autor de commits **Lucas**; nenhum remoto foi adicionado.

## Seleção pública

- `project.godot`, `main.tscn`, `main.gd`, cenas, scripts e ambiente.
- Modelos, texturas e áudio em `assets/`, avisos e manifestos de origem.
- Configurações de importação `.import` e identificadores `.gd.uid`;
  são mantidos, enquanto os caches gerados ficam fora do Git.
- `export_presets.cfg`, com destino relativo e sem credenciais de assinatura.
- README, créditos, licenças de terceiros, documentação selecionada, capturas
  e resultados JSON de validação.
- `.gitignore` e `.gitattributes` para manter a seleção e os tipos dos arquivos.

## Material preservado somente na cópia local

`.godot/`, `dist/`, `proofs/`, `tools/`, documentos históricos não selecionados,
backups, ZIPs, logs e arquivos temporários ficam ignorados. Nenhum desses
arquivos foi apagado. Os experimentos de mocap e retargeting não são parte
da apresentação pública nem dependências do jogo principal.

A varredura dos arquivos selecionados não encontrou padrões de credenciais,
chaves privadas ou caminhos pessoais absolutos. É uma verificação por padrões,
não uma garantia contra todo tipo possível de dado sensível. Os arquivos
existentes de código e recursos do jogo permaneceram idênticos por SHA-256.
Uma cópia formada apenas pelos arquivos selecionados passou pela importação,
abertura e percurso da missão. Veja `evidence/publication-audit.json`.

O executável Windows tem cerca de 104 MiB e excede o
[limite de arquivo de 100 MiB do GitHub](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github).
A pasta da build e o ZIP de aproximadamente 74 MiB não
devem entrar nos commits. Uma eventual distribuição deve ser um anexo de
release separado, somente após autorização. Os assets selecionados têm
arquivos individuais menores que 10 MiB e não exigem Git LFS nesta seleção.

## Antes de tornar o projeto público

1. Revisar o README, as capturas e as limitações, especialmente o skate.
2. Definir se haverá uma licença para o código e elementos autorais. As
   licenças CC0 dos assets não licenciam o código do projeto.
3. Escolher o nome e a visibilidade do repositório GitHub e autorizar a publicação.
4. Somente então configurar o remoto e enviar os commits preparados.
5. Se desejar distribuir a build, aprovar uma release separada, acompanhada
   dos créditos, instruções e avisos de licença.

Não há URL de clone ou download público no README enquanto um repositório
ou uma release não tiver sido efetivamente criado e autorizado.
