# Tutorial — Aparador de vídeos LZ Games

[Voltar ao projeto](../README.md)

Este guia mostra como recortar e compactar vídeos em lote, mantendo a organização das subpastas. As instruções correspondem ao código da versão **1.3.0**.

## Antes de começar

Abra [Releases](https://github.com/luziellacerda/APARADOR-LZ/releases) e, em **Assets** da versão desejada, baixe `LZGames-Aparador-1.3.0-Setup.exe`. Os arquivos aparecem quando o build e os testes dessa release terminam com sucesso. Não confunda **Code → Download ZIP** ou **Source code** com o instalador. Consulte [RELEASE.md](RELEASE.md) para verificar o arquivo ou [COMPILAR.md](COMPILAR.md) para gerar uma instalação local.

O programa exige Windows 10/11 x64 Intel/AMD, .NET Framework 4.8 e Windows PowerShell 5.1. O instalador verifica esses requisitos.

O instalador completo já inclui FFmpeg e ffprobe. Não é necessário baixá-los separadamente, nem ter internet para processar vídeos depois de instalar.

Para instalar:

1. Execute `LZGames-Aparador-1.3.0-Setup.exe` e siga o assistente.
2. Escolha se deseja um atalho na Área de Trabalho; ele é opcional.
3. Abra o programa pelo Menu Iniciar.

A instalação é para o usuário atual. O build automático não possui assinatura digital; o Windows pode exibir **editor desconhecido**. Confira a origem do arquivo e não desative proteções do sistema para executá-lo.

Use uma pequena amostra de vídeos no primeiro teste. Mantenha um backup da coleção: as proteções do aplicativo não substituem uma cópia de segurança.

## 1. Escolher as pastas

Na aba **Pastas**:

1. Ao lado de **Vídeos de origem**, clique em **Escolher** e selecione a pasta principal da coleção.
2. Ao lado de **Salvar resultados em**, clique em **Escolher** e selecione outra pasta.
3. Confira a lista de arquivos. Use **Atualizar** se tiver adicionado ou removido vídeos.

Não é necessário selecionar cada subpasta: a leitura é automática e inclui os níveis abaixo da pasta escolhida.

As pastas padrão são:

```text
Documentos/LZ Games/VIDEOS_ORIGINAIS
Documentos/LZ Games/RECORTADOS_LZGAMES
```

As escolhas de pastas valem para a sessão atual. Ao abrir o programa novamente, confira a origem e a saída. A instalação não move automaticamente uma coleção anterior para essas pastas.

Origem e saída não podem ser a mesma pasta física, mesmo quando acessadas por caminhos diferentes. Se a saída estiver dentro da origem, ela é excluída da leitura para não processar os resultados novamente.

### Como as pastas e os nomes são preservados

Considere esta coleção:

```text
Coleção/                         Prontos/
├── Ação/                        ├── Ação/
│   ├── trailer.mp4               │   ├── trailer.mp4
│   └── Bastidores/              │   └── Bastidores/
│       └── cena.mkv              │       └── cena.mp4
├── Corrida/                     └── Corrida/
│   └── trailer.mov                   └── trailer.mp4
├── anotações.txt
└── Pasta vazia/
```

Selecionando `Coleção` como origem e `Prontos` como saída, o programa recria os caminhos relativos `Ação`, `Ação/Bastidores` e `Corrida` dentro de `Prontos`. Não adiciona outra pasta chamada `Coleção`.

Regras importantes:

- São procurados arquivos `.mp4`, `.mkv`, `.mov`, `.avi`, `.webm` e `.m4v`. O conteúdo também precisa ser um vídeo válido que os componentes de mídia consigam ler.
- Todos os resultados são **MP4**. O nome-base é mantido, mas a extensão pode mudar.
- Nomes iguais em pastas diferentes são preservados: `Ação/trailer.mp4` e `Corrida/trailer.mp4` continuam separados.
- Se uma mesma pasta contiver `trailer.mp4` e `trailer.mkv`, os resultados serão `trailer_mp4.mp4` e `trailer_mkv.mp4`. Se ainda houver conflito entre nomes gerados, é acrescentado um número, como `_2`.
- Arquivos que não são vídeos e pastas vazias **não são copiados**. Esta função organiza os vídeos processados; não faz um espelhamento completo de todos os arquivos.
- Links simbólicos e junctions encontrados durante a leitura são ignorados para evitar ciclos e redirecionamentos para fora da origem.
- Uma pasta sem permissão de leitura pode ser ignorada, com aviso no registro. Confira a fila e o resumo antes de considerar a coleção concluída.

## 2. Definir começo e fim do recorte

Abra a aba **Recorte** e ative **Recortar um trecho**.

- **Começar em (s):** ponto do vídeo original onde o trecho começa.
- **Terminar em (s):** ponto do vídeo original onde o trecho termina. **Não é a duração.**

| Começar em | Terminar em | Trecho salvo |
| --- | --- | --- |
| `7` | `22` | Do segundo 7 ao 22: 15 segundos |
| `10` | `45` | Do segundo 10 ao 45: 35 segundos |
| `0` | `60` | Primeiro minuto |
| `7,5` | `22,25` | Do segundo 7,5 ao 22,25: 14,75 segundos |

Você pode digitar os tempos desejados; **7 e 22 são apenas valores iniciais de exemplo**. Use segundos inteiros ou até três casas decimais, com vírgula ou ponto: `7,5` e `7.5` são aceitos. Não use `00:07`, números negativos ou separadores de milhar. Para 1 minuto e 30 segundos, digite `90`.

O fim precisa ser maior que o começo. Os campos aceitam valores de `0` a `2147483647` segundos; o que pode ser salvo depende da duração real de cada arquivo.

**O mesmo intervalo é aplicado a todos os vídeos da fila.** Para usar intervalos diferentes em grupos de vídeos, processe cada grupo em uma execução separada.

Se o fim informado ultrapassar a duração de um vídeo, o programa usa o fim real daquele vídeo e registra um aviso. Se o começo estiver no fim ou depois do fim do vídeo, aquele arquivo gera um erro em vez de produzir um trecho vazio.

Para processar o vídeo inteiro, desligue **Recortar um trecho**. Os campos de tempo ficam desativados. O recorte também recodifica o vídeo usando as configurações da aba **Compactar**; não é um corte sem recodificação.

## 3. Escolher a compactação

Na aba **Compactar**, selecione **Qualidade da imagem**:

| Perfil | O que prioriza |
| --- | --- |
| **Ultra compacto · H.265** | Arquivos menores, com maior possibilidade de perder detalhes |
| **Equilibrado · H.265** | Compromisso entre qualidade visual e tamanho; é o perfil inicial |
| **Alta qualidade · H.265** | Mais detalhes, com processamento mais demorado e arquivos potencialmente maiores |
| **Compatível · H.264** | Reprodução em mais aparelhos e players; pode produzir arquivos maiores |

A compressão tem perda. O tamanho final depende do original; não há garantia de porcentagem de redução ou de ausência de diferenças visuais. Um arquivo já bastante comprimido pode ficar maior.

### Resolução e fluidez

**Resolução máxima:** Original, 1080p, 720p ou 480p. As opções limitadas reduzem o vídeo para caber nas dimensões correspondentes, mantendo a proporção e sem ampliar deliberadamente um vídeo menor. A opção **Original** evita essa redução, mas a imagem ainda é recodificada; dimensões ímpares podem receber um pequeno ajuste de preenchimento para compatibilidade.

**Fluidez máxima:** Original, 60 FPS, 30 FPS ou 24 FPS. As opções numéricas limitam a taxa de quadros; reduzir FPS pode deixar movimentos menos suaves. Se a taxa original não puder ser identificada, a taxa selecionada é aplicada.

O padrão inicial é **Equilibrado · H.265, 720p e 30 FPS**. Se a prioridade for manter dimensões e fluidez, escolha **Original** nos dois campos e avalie o resultado com **Alta qualidade**. Isso ainda não torna a compactação sem perda.

### Manter ou remover áudio

- Ative **Manter o som do vídeo** para incluir o áudio. Ele é recodificado em AAC, com a qualidade escolhida: 64k, 96k, 128k ou 192k.
- Desative para gerar um arquivo sem som. O campo de qualidade do áudio fica desativado.

A configuração inicial mantém o áudio em 128k. Manter áudio não cria som em um vídeo que não o possui. O programa processa o primeiro fluxo de vídeo e, quando o som está ativado, os fluxos de áudio; não é uma ferramenta de preservação integral de legendas, anexos, menus ou outros recursos do arquivo original.

## 4. Executar e conferir

1. Confira a origem, a saída, o intervalo e as configurações.
2. Clique em **Recortar vídeos**, quando o recorte estiver ativado, ou **Compactar vídeos**, quando estiver desligado.
3. Acompanhe a fila, o progresso do arquivo, o progresso do lote e o resumo.
4. Ao terminar, clique em **Abrir resultados**.
5. Reproduza uma amostra dos arquivos e confirme duração, som, imagem e organização antes de copiar a coleção pronta para outro local.

Os vídeos originais não são substituídos pelo processamento. O resultado é criado em um arquivo temporário, validado e só então publicado no destino. Cancelar interrompe o trabalho em andamento; os resultados que já foram concluídos permanecem na saída.

### Refazer um recorte ou mudar a qualidade

Por padrão, um resultado já existente é **ignorado e preservado**. Isso evita sobrescritas acidentais, mas significa que mudar o intervalo e executar de novo não altera automaticamente um MP4 já salvo.

Para refazer:

1. Se quiser conservar os resultados anteriores, escolha uma **nova pasta de saída**.
2. Se quiser substituí-los, ative **Substituir resultados**, na aba **Pastas**, antes de iniciar.

A substituição só ocorre depois que o novo resultado termina e passa pelas verificações. A opção não autoriza o programa a substituir um vídeo identificado como original.

## Solução de problemas

| Situação | O que conferir |
| --- | --- |
| A fila está vazia | Selecione a origem correta, confira as extensões reconhecidas e clique em **Atualizar**. Links e junctions são ignorados. |
| O recorte parece não ter mudado | Veja se o arquivo foi marcado como **Ignorado**. Escolha outra saída ou ative **Substituir resultados**. |
| O resultado tem 15 segundos ao usar 7 e 22 | Esse é o comportamento esperado: o segundo campo é o fim, não a duração. |
| Um vídeo não aceita o recorte | O início deve ser menor que a duração daquele vídeo, e o fim deve ser maior que o início. Consulte a mensagem da fila. |
| O player não abre o resultado H.265 | Teste o perfil **Compatível · H.264** em uma nova saída. |
| O arquivo ficou maior | Compare os perfis e as configurações. Não há economia garantida para todo original. |
| FFmpeg ou ffprobe ausente | Confira a instalação completa e as dependências. Não copie apenas o EXE principal para outra pasta. |
| O instalador encontra o programa em uso | Termine ou cancele o processamento e feche o programa antes de tentar atualizar. O instalador não o encerra à força. |

Em caso de falha da aplicação, os diagnósticos locais ficam normalmente em `%LOCALAPPDATA%\LZGames\Logs`; se esse local falhar, pode ser usada a pasta temporária `LZGames-Logs`. Eles não são enviados automaticamente. Revise e remova caminhos pessoais antes de compartilhá-los em uma [issue](https://github.com/luziellacerda/APARADOR-LZ/issues).

## Desinstalar

Use **Aplicativos** nas Configurações do Windows ou o atalho de desinstalação no Menu Iniciar. O desinstalador remove os arquivos conhecidos do programa e preserva os vídeos e resultados. Ele não é uma ferramenta para apagar sua coleção ou limpar todas as pastas pessoais.

Para detalhes da implementação e das verificações, consulte [Compilar](COMPILAR.md), [Testes](TESTES.md) e [Dependências](DEPENDENCIAS.md).
