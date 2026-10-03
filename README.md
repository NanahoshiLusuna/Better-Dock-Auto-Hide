# Better Dock Auto Hide

[한국어](#한국어) · [English](#english) · [日本語](#日本語)

<a name="한국어"></a>

# 한국어

[English](#english) · [日本語](#日本語) · [한국어](#한국어)

**Better Dock Auto Hide**는 창의 위치를 감지하여 **macOS Dock을 자동으로 숨기거나 표시하는 가벼운 Swift 메뉴 막대 앱**입니다.

Dock 가장자리 근처의 창을 감지하여 창의 위치에 따라 macOS의 Dock 자동 숨김 상태를 자동으로 변경합니다.

**macOS 13.0 이상을 지원합니다.**

## 주요 기능

* 창 위치에 따른 Dock 자동 숨김
* 다중 모니터 지원
* Dock 가장자리 감지 거리 설정
* Dock 표시 지연 시간 설정
* 창을 숨겨진 Dock 영역까지 확장
* macOS 메뉴 막대 앱
* 온도 및 날씨 표시
* 앱 종료 시 기존 Dock 자동 숨김 설정 복원

## 빌드

macOS에서 Swift Package Manager로 빌드할 수 있습니다.

```sh
swift build -c release
```

## 작동 방식

* Dock이 있는 화면에서 창이 설정한 감지 거리만큼 Dock 쪽 가장자리에 가까워지면 Dock을 자동으로 숨깁니다.
* 해당 화면의 모든 창이 가장자리에서 멀어지면 앱 실행 전에 사용하던 Dock 자동 숨김 상태로 돌아갑니다.
* 다른 모니터의 창을 사용하더라도 필요 이상으로 Dock 상태를 변경하지 않습니다.
* 앱을 종료하면 앱 실행 전의 Dock 자동 숨김 설정을 복원합니다.

## 메뉴 막대 설정

| 설정                                     | 설명                                            |
| -------------------------------------- | --------------------------------------------- |
| Automatic Mode (Window Edge Detection) | 창 위치에 따라 Dock 자동 숨김을 자동으로 변경합니다.              |
| Dock Auto Hide                         | Dock 자동 숨김을 수동으로 켜거나 끕니다.                     |
| Show Dock for Windows Over Full Screen | 전체 화면 또는 확장된 창 위에서 Dock을 표시합니다.               |
| Expand Windows into Dock Area          | 창을 Dock 영역까지 확장합니다.                           |
| Dock Reveal Delay                      | Dock이 나타날 때까지의 지연 시간을 설정합니다.                  |
| Edge Threshold                         | Dock 가장자리 감지 거리를 16 / 24 / 32 / 48 px로 설정합니다. |
| Dock Icon                              | Dock 아이콘과 갱신 주기를 설정합니다.                       |

## 권한

| 권한                  | 사용 목적                       |
| ------------------- | --------------------------- |
| 접근성 (Accessibility) | 창 확장 기능에 사용합니다.             |
| 자동화 (System Events) | Dock 자동 숨김 상태를 변경할 때 사용합니다. |
| 위치                  | 온도 및 날씨 정보에 사용합니다.          |

## 제한 사항

* macOS 전체 화면 모드는 시스템에서 관리합니다.
* 다른 모니터의 화면 가장자리로 마우스를 이동하면 Dock이 해당 모니터로 이동할 수 있습니다.
* 일부 앱에서는 최대화된 창의 크기 변경이 제한될 수 있습니다.

---

## License

No license file is currently included in this repository.

---

<a name="english"></a>

## English

A lightweight **Swift macOS menu bar utility** that automatically hides and shows the **macOS Dock** based on window position.

Better Dock Auto Hide monitors windows near the Dock edge and changes the system Dock auto-hide state. It supports **multi-monitor setups**, configurable edge detection, Dock reveal delay, and optional window expansion into the Dock area.

**Requires macOS 13.0 or later.**

### Features

* Automatic Dock auto-hide based on window position
* Multi-monitor support
* Configurable edge threshold
* Configurable Dock reveal delay
* Optional window expansion into the Dock area
* macOS menu bar app
* Optional temperature and weather display
* Restores the original Dock auto-hide setting when the app exits

### Build

This repository is a Swift Package Manager executable.

Build from source on macOS:

```sh
swift build -c release
```

The repository also includes a built `DockAutoHide.app` bundle and `DockAutoHide.zip` distribution archive.

### How It Works

* When a window on a screen reaches the configured Dock edge threshold, the Dock is automatically hidden.
* When all windows on that screen move away from the edge, the Dock returns to the auto-hide state that was active before the app started.
* Working with windows on another monitor does not unnecessarily change the Dock state.
* When the app quits, the original Dock auto-hide setting is restored.

When a window expanded by double-clicking its title bar is being used, the window can optionally expand into the space occupied by the hidden Dock.

### Dock Icon

The menu bar icon can optionally display the current temperature and a weather icon.

Supported information includes:

* Temperature
* Weather/time-based icons such as sun, moon, rain, and clouds
* Configurable rotation interval: 5 / 10 / 15 / 30 / 60 seconds

If location permission is unavailable, the app can use the last known location or an approximate network location for weather information.

### Menu Bar Settings

| Setting                                | Description                                                                                        |
| -------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Automatic Mode (Window Edge Detection) | Automatically changes Dock auto-hide based on window position.                                     |
| Dock Auto Hide                         | Manually enables or disables Dock auto-hide. Automatic Mode pauses while this is enabled.          |
| Show Dock for Windows Over Full Screen | Shows the Dock when working with smaller windows over a full-screen or expanded window.            |
| Expand Windows into Dock Area          | Expands double-click-maximized windows into the Dock area.                                         |
| Dock Reveal Delay                      | Controls how long the pointer must remain at the edge before the hidden Dock appears.              |
| Edge Threshold                         | Sets the distance used to detect whether a window has reached the Dock edge: 16 / 24 / 32 / 48 px. |
| Dock Icon                              | Enables the icon and configures its rotation interval.                                             |

### Permissions

| Permission                 | When it is used                                                                                    |
| -------------------------- | -------------------------------------------------------------------------------------------------- |
| Accessibility              | Requested only when window expansion is enabled and permission is required.                        |
| Automation (System Events) | Requested by macOS when the app changes Dock auto-hide.                                            |
| Location                   | Requested when no location has previously been determined; used for temperature and weather icons. |

### Limitations

* macOS full-screen mode entered with the green window button is handled by the system.
* Moving the mouse to the edge of another monitor can cause macOS to move the Dock to that monitor.
* Some applications may prevent their windows from being resized while maximized.

[⬆ Back to language selection](#better-dock-auto-hide)

---

<a name="日本語"></a>

# 日本語

[English](#english) · [日本語](#日本語) · [한국어](#한국어)

**Better Dock Auto Hide** は、ウインドウの位置に応じて **macOS の Dock を自動的に表示・非表示にする軽量なSwiftメニューバーアプリ**です。

Dock の端付近にあるウインドウを監視し、ウインドウの位置に応じて macOS の Dock の自動表示／非表示を切り替えます。

**macOS 13.0 以降に対応しています。**

## 主な機能

* ウインドウの位置に応じた Dock の自動非表示
* マルチモニター対応
* Dock 端部の検出距離を設定可能
* Dock 表示までの遅延時間を設定可能
* ウインドウを Dock の領域まで拡張するオプション
* macOS メニューバーアプリ
* 温度・天気情報の表示
* アプリ終了時に元の Dock 自動非表示設定を復元

## ビルド

macOS で Swift Package Manager を使用してビルドできます。

```sh
swift build -c release
```

## 動作の仕組み

* Dock のある画面でウインドウが設定した検出距離まで Dock 側の端に近づくと、Dock を自動的に非表示にします。
* その画面にあるすべてのウインドウが端から離れると、アプリ起動前の Dock 自動非表示状態に戻します。
* 別のモニターでウインドウを操作しても、必要以上に Dock の状態を変更しません。
* アプリを終了すると、起動前の Dock 自動非表示設定が復元されます。

## メニューバー設定

| 設定                                     | 説明                                            |
| -------------------------------------- | --------------------------------------------- |
| Automatic Mode (Window Edge Detection) | ウインドウの位置に応じて Dock の自動非表示を切り替えます。              |
| Dock Auto Hide                         | Dock の自動非表示を手動で有効／無効にします。                     |
| Show Dock for Windows Over Full Screen | フルスクリーンまたは拡大されたウインドウの上で Dock を表示します。          |
| Expand Windows into Dock Area          | ウインドウを Dock の領域まで拡張します。                       |
| Dock Reveal Delay                      | Dock が表示されるまでの時間を設定します。                       |
| Edge Threshold                         | Dock の端を検出する距離を 16 / 24 / 32 / 48 px から設定します。 |
| Dock Icon                              | Dock アイコンと更新間隔を設定します。                         |

## 権限

| 権限                         | 使用目的                     |
| -------------------------- | ------------------------ |
| Accessibility              | ウインドウ拡張機能に使用します。         |
| Automation (System Events) | Dock の自動非表示を変更する際に使用します。 |
| Location                   | 温度・天気情報の取得に使用します。        |

## 制限事項

* macOS のフルスクリーンモードはシステムによって管理されます。
* 別のモニターの画面端へマウスを移動すると Dock がそのモニターへ移動する場合があります。
* 一部のアプリケーションでは最大化されたウインドウのサイズ変更が制限される場合があります。

[⬆ 言語選択に戻る](#better-dock-auto-hide)
