import SwiftUI
import UIKit
import CoreImage
import Charts
import Core

// MARK: - Chart (화면 리포트와 공유 카드가 공용)

struct SmileReportChart: View {
    let samples: [Double]
    // 기본값은 인앱 다크(카메라 위 오버레이) — 공유 카드는 라이트 값을 주입한다.
    var lineColor: Color = .green
    var areaColor: Color = .green.opacity(0.15)
    var labelColor: Color = .white.opacity(0.6)
    var gridColor: Color = .white.opacity(0.15)
    var ruleColor: Color = .white.opacity(0.4)

    var body: some View {
        Chart {
            ForEach(points, id: \.time) { point in
                LineMark(
                    x: .value("시간", point.time),
                    y: .value("미소 강도", point.score)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)

                AreaMark(
                    x: .value("시간", point.time),
                    y: .value("미소 강도", point.score)
                )
                .foregroundStyle(areaColor)
                .interpolationMethod(.monotone)
            }

            RuleMark(y: .value("기준", AppConstants.PracticeMirror.smileThreshold))
                .foregroundStyle(ruleColor)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("미소 기준")
                        .font(FMTypography.caption2)
                        .foregroundStyle(labelColor)
                }
        }
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(values: [0, 0.5, 1]) { value in
                AxisGridLine().foregroundStyle(gridColor)
                AxisValueLabel {
                    if let score = value.as(Double.self) {
                        Text("\(Int(score * 100))%")
                            .font(FMTypography.caption2)
                            .foregroundStyle(labelColor)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(gridColor)
                AxisValueLabel {
                    if let seconds = value.as(Double.self) {
                        Text(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))
                            .font(FMTypography.caption2)
                            .monospacedDigit()
                            .foregroundStyle(labelColor)
                    }
                }
            }
        }
    }

    /// 차트 표시용 다운샘플 — 긴 세션도 240포인트 이하로 구간 평균해 그린다.
    private var points: [(time: Double, score: Double)] {
        guard !samples.isEmpty else { return [] }
        let maxPoints = 240
        let chunkSize = max(1, Int((Double(samples.count) / Double(maxPoints)).rounded(.up)))
        return stride(from: 0, to: samples.count, by: chunkSize).map { start in
            let chunk = samples[start..<min(start + chunkSize, samples.count)]
            let mean = chunk.reduce(0, +) / Double(chunk.count)
            return (Double(start) * AppConstants.PracticeMirror.sampleInterval, mean)
        }
    }
}

// MARK: - Share Card

/// 공유용 미소 리포트 카드 — ImageRenderer로 1080×1350(540×675pt ×2, 인스타 피드 4:5) 이미지로 렌더링된다.
/// 이미지라 Dynamic Type 영향이 없도록 고정 폰트 크기를 사용한다.
struct SmileReportShareCard: View {
    let samples: [Double]
    let smileRatio: Double
    let averageScore: Double
    let durationText: String
    let date: Date

    // 브랜드 팔레트 (FMColors raw 값) — 이미지라 다크 모드 분기 없이 고정
    private let navyInk = Color(red: 0.02, green: 0.09, blue: 0.40)
    private let coral = Color(red: 1.0, green: 0.498, blue: 0.624)
    private let coralDeep = Color(red: 0.87, green: 0.30, blue: 0.45)
    private let sky = Color(red: 0.29, green: 0.66, blue: 0.85)

    var body: some View {
        ZStack {
            Color.white

            // 배경 장식 블롭 — 화이트 톤을 해치지 않게 아주 은은하게
            Circle()
                .fill(coral.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: 220, y: -290)
            Circle()
                .fill(sky.opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 70)
                .offset(x: -230, y: 310)

            VStack(alignment: .leading, spacing: 20) {
                header

                Text("오늘의 미소 연습 완료 ✨")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(navyInk.opacity(0.75))

                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text("\(Int(smileRatio * 100))%")
                        .font(.system(size: 60, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(coralDeep)
                    Text("미소 유지율")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(navyInk.opacity(0.6))
                }

                chartCard

                HStack(spacing: 36) {
                    stat(title: "측정 시간", value: durationText)
                    stat(title: "평균 미소 강도", value: "\(Int(averageScore * 100))%")
                    Spacer()
                }

                Spacer(minLength: 0)

                footer
            }
            .padding(40)
        }
        .frame(width: 540, height: 675)
        .environment(\.colorScheme, .light)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)

            if let qr = Self.appStoreQR {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(navyInk.opacity(0.12), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("FlyMate에서 미소 연습을 시작해보세요 ✈️")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(navyInk.opacity(0.75))
                Text("QR을 스캔하면 App Store로 이동해요")
                    .font(.system(size: 12))
                    .foregroundStyle(navyInk.opacity(0.5))
            }

            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let icon = Self.appIcon {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .shadow(color: coral.opacity(0.25), radius: 8, y: 3)
            } else {
                FMPracticeSymbol(size: 48)
            }

            Text("FlyMate")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(navyInk)

            Spacer()

            Text(date, format: .dateTime.year().month().day())
                .font(.system(size: 14))
                .monospacedDigit()
                .foregroundStyle(navyInk.opacity(0.5))
        }
    }

    private var chartCard: some View {
        SmileReportChart(
            samples: samples,
            lineColor: coralDeep,
            areaColor: coral.opacity(0.18),
            labelColor: navyInk.opacity(0.5),
            gridColor: navyInk.opacity(0.08),
            ruleColor: navyInk.opacity(0.3)
        )
        .frame(height: 160)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(coral.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: coral.opacity(0.15), radius: 14, y: 5)
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(navyInk.opacity(0.55))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(navyInk)
        }
    }

    /// App Store 링크 QR — CoreImage 내장 생성기라 의존성 없음
    private static let appStoreQR: UIImage? = {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(AppConstants.ServiceURL.appStore.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        // 셀당 10px로 확대 후 비트맵화 — 카드 축소 표시에도 또렷하게
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }()

    /// 메인 번들의 앱 아이콘 (Info.plist CFBundleIcons 경유)
    private static let appIcon: UIImage? = {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last else { return nil }
        return UIImage(named: name)
    }()
}
