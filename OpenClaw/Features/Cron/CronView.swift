import SwiftUI

struct CronView: View {
    @EnvironmentObject var gateway: GatewayClient
    @State private var jobs: [CronJob] = []
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.surfaceBase.ignoresSafeArea()
            BlueprintGrid()

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "Scheduled Tasks")
                    Text("Cron Jobs")
                        .font(.headline(28))
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if isLoading && jobs.isEmpty {
                    Spacer()
                    HStack { Spacer(); ProgressView().tint(.ocPrimary); Spacer() }
                    Spacer()
                } else if jobs.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.textTertiary)
                        Text("NO CRON JOBS")
                            .font(.label(11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(jobs) { job in
                                CronJobCard(job: job) {
                                    await toggleJob(job)
                                } onRun: {
                                    await runJob(job)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await loadJobs() } } label: {
                    Image(systemName: "arrow.clockwise").foregroundStyle(Color.ocPrimary)
                }
            }
        }
        .task { await loadJobs() }
    }

    private func loadJobs() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await gateway.sendRequest(method: "cron.list", params: ["includeDisabled": true])
            guard response.ok,
                  let payload = response.payload?.dict,
                  let arr = payload["jobs"] as? [[String: Any]] else { return }
            jobs = arr.compactMap { dict -> CronJob? in
                guard let id = dict["id"] as? String else { return nil }
                let sched = dict["schedule"] as? [String: Any]
                let pay = dict["payload"] as? [String: Any]
                return CronJob(
                    id: id, name: dict["name"] as? String,
                    enabled: dict["enabled"] as? Bool ?? true,
                    schedule: CronJob.CronSchedule(kind: sched?["kind"] as? String, expr: sched?["expr"] as? String, everyMs: sched?["everyMs"] as? Int),
                    payload: CronJob.CronPayload(kind: pay?["kind"] as? String, text: pay?["text"] as? String, message: pay?["message"] as? String)
                )
            }
        } catch {}
    }

    private func toggleJob(_ job: CronJob) async {
        _ = try? await gateway.sendRequest(method: "cron.update", params: ["jobId": job.id, "patch": ["enabled": !job.enabled] as [String: Any]])
        await loadJobs()
    }

    private func runJob(_ job: CronJob) async {
        _ = try? await gateway.sendRequest(method: "cron.run", params: ["jobId": job.id])
        Haptics.notification(.success)
    }
}

struct CronJobCard: View {
    let job: CronJob
    let onToggle: () async -> Void
    let onRun: () async -> Void
    @State private var isEnabled: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(job.displayName)
                    .font(.body(14, weight: .semibold))
                    .foregroundStyle(isEnabled ? Color.textPrimary : Color.textTertiary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(job.scheduleDescription)
                            .font(.label(10))
                    }
                    .foregroundStyle(Color.textTertiary)

                    if let kind = job.payload?.kind {
                        KindBadge(text: kind, color: kind == "agentTurn" ? Color.ocPrimary : Color.ocTertiary)
                    }
                }

                if let text = job.payload?.text ?? job.payload?.message {
                    Text(text)
                        .font(.body(11))
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(spacing: 10) {
                Button { Task { await onRun() } } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.ocPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.ocPrimary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .scaleEffect(0.75)
                    .tint(.ocPrimary)
                    .onChange(of: isEnabled) { Task { await onToggle() } }
            }
        }
        .padding(14)
        .vanguardCard()
        .opacity(isEnabled ? 1 : 0.5)
        .onAppear { isEnabled = job.enabled }
    }
}
