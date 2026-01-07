[![](https://img.shields.io/badge/sagasu_5.0.0-passing-green)](https://github.com/gongahkia/sagasu-5/releases/tag/5.0.0)
![](https://github.com/gongahkia/sagasu-5/actions/workflows/release-dmg.yml/badge.svg)

# `Sagasu 5`

<p align="center">
    <img src="./asset/logo/logo-five.png" width=55% height=55%>
</p>

Run [it](#other-notes) back *(but as a [MacOS](https://www.apple.com/os/macos/) menu bar app)*.

## Stack

* *Frontend*: [SwiftUI](https://developer.apple.com/swiftui/)
* *Backend*: [Swift](https://developer.apple.com/swift/)
* *API*: [`Sagasu 4`'s data](#data)

## Rationale

See [this](https://github.com/gongahkia/sagasu#rationale), [this](https://github.com/gongahkia/sagasu-2#rationale), [this](https://github.com/gongahkia/sagasu-3#rationale) and [this](https://github.com/gongahkia/sagasu-4#rationale).

## Architecture

```mermaid
flowchart LR
  %% Sagasu 5 - Architecture-as-code (Mermaid)

  %% ===== Styles =====
  classDef app fill:#E8F2FF,stroke:#5B8DEF,stroke-width:1px,color:#0B1F44;
  classDef service fill:#EFFFF5,stroke:#3AA76D,stroke-width:1px,color:#062A17;
  classDef data fill:#FFF6E5,stroke:#D49B3A,stroke-width:1px,color:#3B2103;
  classDef external fill:#F4F5F7,stroke:#8A8F98,stroke-width:1px,color:#1F2328;
  classDef user fill:#F2E9FF,stroke:#7B61FF,stroke-width:1px,color:#20124D;

  %% ===== User / Device =====
  subgraph mac[macOS Device]
    U[User]
    class U user

    subgraph s5[Sagasu 5 - Menu Bar App]
      MB[MenuBarExtra - SwiftUI]
      UI[ContentView - Menu UI]
      AS[AppState\n- schedules refresh\n- holds published state\n- computes menu title]
      class MB,UI,AS app
    end
  end

  U -->|clicks menu bar icon| MB
  MB --> UI
  UI <-->|observes| AS

  %% ===== Networking / Fetch =====
  subgraph net[Fetch + Decode]
    SCHED[Daily refresh @ 08:15 SGT\nmanual refresh]
    HTTP[URLSession GET\n3 endpoints in parallel]
    DEC[JSONDecoder\ndecode into Models.swift]
    class SCHED,HTTP,DEC service
  end

  AS --> SCHED
  SCHED --> HTTP
  HTTP --> DEC
  DEC --> AS

  %% ===== Data Source (external) =====
  subgraph ext[External data producer: Sagasu 4]
    CRON[GitHub Actions - cron]
    SCRAPE[Scraper job\ncollects rooms/bookings/tasks]
    REPO[(GitHub repo: sagasu-4\nbackend/log/*.json)]
    class CRON,SCRAPE external
    class REPO data

    CRON --> SCRAPE
    SCRAPE -->|commits JSON logs| REPO
  end

  %% ===== Consumption =====
  REPO -->|raw.githubusercontent.com\nGET scraped_log.json| HTTP
  REPO -->|raw.githubusercontent.com\nGET scraped_bookings.json| HTTP
  REPO -->|raw.githubusercontent.com\nGET scraped_tasks.json| HTTP

  %% ===== Notes =====
  AS -.->|updates menu title\ne.g. x/y free| MB
```

## Screenshots

<div align="center">
    <img src="./asset/reference/1.png" width="48%">
    <img src="./asset/reference/2.png" width="48%">
</div>

## Usage

Note that `Sagasu 5` *(like `Sagasu 4`)* was primarily made for my own use. The most immediate and easiest way for others to access `Sagasu 5` is via [direct download](https://support.apple.com/en-us/102662) of the `Sagasu.dmg` [here]().

If you are interested in cloning and building `Sagasu 5` yourself, the below instructions are for you.

1. First execute the below to install the repository on your local machine.

```console
$ git clone https://github.com/gongahkia/sagasu-5 && cd sagasu-5
```

2. Next install Xcode from the [Mac App Store](https://apps.apple.com/us/app/xcode/id497799835?mt=12).

3. Finally run the below command to build the project with [Xcode](https://developer.apple.com/xcode/) via the [Xcode CLI toolkit](https://mac.install.guide/commandlinetools/).

```console
$ swift build
```

4. Alternatively open the project directly within Xcode and build it via the [GUI view](https://developer.apple.com/documentation/xcode/building-and-running-an-app).

## Data

For those interested, `Sagasu 5` is currenly configured to pull daily data from `Sagasu 4`'s below [publicly available endpoints](https://github.com/gongahkia/sagasu-4).

* `backend/log/scraped_log.json`
* `backend/log/scraped_bookings.json`
* `backend/log/scraped_tasks.json`

## Other notes

`Sagasu 5` is where it is today because of the below projects. 

* [Sagasu](https://github.com/gongahkia/sagasu)
* [Sagasu 2](https://github.com/gongahkia/sagasu-2)
* [Sagasu 3](https://github.com/gongahkia/sagasu-3)
* [Sagasu 4](https://github.com/gongahkia/sagasu-4)