import SwiftUI
import Charts

struct MetricsView: View {
    @EnvironmentObject private var store: WorkoutStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                attendanceCard
                streakCard
                prCard
                averageDurationCard
            }
            .padding()
        }
        .navigationTitle("Metrics")
    }

    private var attendanceCard: some View {
        let snapshot = store.snapshotMetrics()
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Attendance", systemImage: "calendar")
                Spacer()
                Text("Last sync: \(snapshot.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                statPill(value: snapshot.workoutsThisWeek, label: "This week")
                statPill(value: snapshot.workoutsThisMonth, label: "Last 30 days")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var streakCard: some View {
        let streak = store.streakCount()
        return VStack(alignment: .leading, spacing: 8) {
            Label("Streak", systemImage: "flame.fill")
            Text("\(streak) day streak")
                .font(.title.bold())
            ProgressView(value: min(Double(streak) / 7, 1)) {
                Text("Goal: 7-day streaks")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var prCard: some View {
        let data = store.exercises.compactMap { exercise -> (Exercise, Double)? in
            guard let pr = store.pr(for: exercise.id) else { return nil }
            return (exercise, pr)
        }
        return VStack(alignment: .leading, spacing: 12) {
            Label("PRs", systemImage: "chart.line.uptrend.xyaxis")
            Chart(data, id: \.0.id) { item in
                BarMark(
                    x: .value("Exercise", item.0.name),
                    y: .value("Weight", item.1)
                )
            }
            .frame(minHeight: 200)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var averageDurationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Average duration", systemImage: "clock.arrow.circlepath")
            Text("\(store.averageDurationMinutes(), format: .number.precision(.fractionLength(0...1))) minutes")
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statPill(value: Int, label: String) -> some View {
        VStack(alignment: .leading) {
            Text("\(value)")
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
