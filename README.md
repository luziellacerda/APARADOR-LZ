<p align="center"><img src="assets/LZGames.png" width="96" height="96" alt="LZ Games"></p>

# Aparador de vídeos LZ Games

Recorte e compacte uma coleção de vídeos no Windows, mantendo a organização das subpastas.

**Versão do código: 1.3.0 · Windows 10/11 x64 · Processamento local**

[Tutorial de uso](docs/TUTORIAL.md) · [Compilar e gerar instalador](docs/COMPILAR.md) · [Testes](docs/TESTES.md) · [Dependências](docs/DEPENDENCIAS.md)

## O que o programa faz

- Lê os vídeos da pasta escolhida e de suas subpastas.
- Recorta pelo **começo e fim em segundos**: de `7` a `22` salva um trecho de 15 segundos. Os tempos são livres, inclusive com casas decimais.
- Compacta em H.265 ou H.264, com opções de resolução e taxa de quadros.
- Permite manter o som ou gerar vídeos sem áudio.
- Salva em MP4, reproduzindo a estrutura de pastas e preservando os nomes-base quando não há colisão.
- Mostra fila, progresso e resultados no painel. Os originais não são substituídos pelo processamento.

Não é um copiador completo de pastas: arquivos que não são vídeos e pastas vazias não são copiados. Links e junctions encontrados na leitura são ignorados. Veja as regras e exceções no [tutorial](docs/TUTORIAL.md#como-as-pastas-e-os-nomes-são-preservados).

## Disponibilidade do instalador

**Este repositório publica o código-fonte e as instruções de compilação; não há instalador público ou executável para baixar nesta entrega.**

Um instalador 1.3.0 foi gerado e testado para uso local. A publicação desse pacote foi adiada porque faltam materiais completos de procedência, licenciamento e fontes correspondentes dos binários FFmpeg/ffprobe reaproveitados. Esses binários não estão no Git.

Para preparar seu ambiente e gerar um instalador local, siga [Compilar e gerar instalador](docs/COMPILAR.md) e [Dependências de terceiros](docs/DEPENDENCIAS.md). O botão **Code → Download ZIP** baixa o projeto, não um programa pronto para instalar.

## Uso em cinco passos

Depois de instalar uma compilação local confiável:

1. Abra **Aparador de vídeos LZ Games**.
2. Em **Pastas**, escolha a pasta principal de origem e uma pasta diferente para os resultados.
3. Em **Recorte**, ative **Recortar um trecho** e informe **Começar em (s)** e **Terminar em (s)**. Deixe desligado para processar o vídeo inteiro.
4. Em **Compactar**, escolha o perfil, a resolução, a fluidez e se deseja manter o áudio.
5. Clique em **Recortar vídeos** ou **Compactar vídeos** e, ao terminar, em **Abrir resultados**.

O mesmo intervalo e as mesmas configurações são aplicados a toda a fila. Para refazer resultados já existentes, escolha outra saída ou ative **Substituir resultados**, na aba **Pastas**.

### Organização preservada

```text
Origem/                         Resultados/
├── Ação/                       ├── Ação/
│   ├── trailer.mp4              │   ├── trailer.mp4
│   └── Extras/                 │   └── Extras/
│       └── cena.mkv             │       └── cena.mp4
└── Corrida/                    └── Corrida/
    └── trailer.mov                 └── trailer.mp4
```

Os resultados começam **dentro da pasta de saída escolhida**; não é criada uma cópia extra do nome da pasta raiz. Assim, o conteúdo processado pode ser copiado mantendo sua organização relativa.

## Qualidade e tamanho

A compactação usa recodificação **com perda**. Não existe promessa de redução drástica sem perda de qualidade, nem um percentual fixo de economia: o resultado depende do vídeo original e das configurações. Um arquivo já bem compactado pode até ficar maior.

**Alta qualidade** preserva mais detalhes; **Ultra compacto** prioriza arquivos menores. Reduzir resolução ou FPS também reduz detalhes ou fluidez. Consulte a [comparação dos perfis](docs/TUTORIAL.md#3-escolher-a-compactação) e teste um vídeo antes de processar uma coleção grande.

## Requisitos

- Windows 10 ou 11, **x64 Intel/AMD**.
- .NET Framework 4.8 e Windows PowerShell 5.1.
- FFmpeg e ffprobe compatíveis, conforme [Dependências](docs/DEPENDENCIAS.md).
- Espaço disponível para os resultados e os arquivos temporários de processamento.

A interface é Windows Forms em C#. O processamento PowerShell é embutido no executável; FFmpeg/ffprobe ficam em `bin` na instalação. Não basta copiar apenas o EXE principal para outro computador.

## Projeto e documentação

```text
src/                   Interface, inicialização e processamento
assets/                Ícone e identidade visual
installer/             Definição do instalador NSIS
tests/                 Testes automatizados
docs/                  Tutorial, compilação, testes e dependências
vendor/ffmpeg/         Dependências locais, não versionadas
Build-App.ps1          Compilação do aplicativo
Build-Installer.ps1    Geração do instalador
```

Os testes e seus limites estão descritos em [TESTES.md](docs/TESTES.md). Validações locais não garantem compatibilidade com todo vídeo ou computador.

Encontrou um problema? Abra uma [issue](https://github.com/luziellacerda/APARADOR-LZ/issues) com a versão, as configurações de início/fim, o formato do vídeo e a mensagem de erro. Remova nomes pessoais, caminhos privados e outras informações sensíveis antes de anexar registros ou imagens.

## Licença e terceiros

Ainda não foi atribuída uma licença explícita ao código da aplicação. A disponibilidade do código neste repositório não declara uma licença MIT, GPL ou outra licença para o projeto.

FFmpeg, ffprobe e NSIS têm seus próprios termos. Antes de redistribuir qualquer pacote compilado, consulte [DEPENDENCIAS.md](docs/DEPENDENCIAS.md) e reúna os materiais exigidos pelas licenças das versões utilizadas.
