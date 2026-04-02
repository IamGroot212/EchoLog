import SwiftUI

struct SessionHistoryView: View {
    @State private var sessionManager = SessionManager.shared
    @State private var searchText = ""
    @State private var selectedSession: Session?
    @State private var sessionToDelete: Session?
    @State private var showDeleteConfirmation = false

    private var filteredSessions: [Session] {
        if searchText.isEmpty {
            return sessionManager.sessions
        }
        return sessionManager.sessions.filter { session in
            session.folderName.localizedCaseInsensitiveContains(searchText) ||
            session.capturedApps.contains { $0.displayName.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(filteredSessions, selection: $selectedSession) { session in
                SessionRow(session: session)
                    .tag(session)
                    .contextMenu {
                        Button("Show in Finder") {
                            let folder = SessionManager.shared.sessionFolder(for: session)
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
                        }
                        Divider()
                        Button("Delete...", role: .destructive) {
                            sessionToDelete = session
                            showDeleteConfirmation = true
                        }
                    }
            }
            .searchable(text: $searchText, prompt: "Search sessions...")
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem {
                    Button(action: { sessionManager.loadSessions() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh")
                }
            }
            .confirmationDialog(
                "Delete Session?",
                isPresented: $showDeleteConfirmation,
                presenting: sessionToDelete
            ) { session in
                Button("Delete", role: .destructive) {
                    deleteSession(session)
                }
            } message: { session in
                Text("Delete \"\(session.folderName)\" and all its files? This cannot be undone.")
            }
        } detail: {
            if let session = selectedSession {
                SessionDetailView(
                    session: session,
                    onDelete: {
                        selectedSession = nil
                        sessionManager.loadSessions()
                    }
                )
            } else {
                ContentUnavailableView(
                    "Select a Session",
                    systemImage: "waveform",
                    description: Text("Choose a session from the sidebar to view its transcript and summary.")
                )
            }
        }
        .onAppear {
            sessionManager.loadSessions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            sessionManager.loadSessions()
        }
    }

    private func deleteSession(_ session: Session) {
        if selectedSession?.id == session.id {
            selectedSession = nil
        }
        try? sessionManager.deleteSession(session)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDate)
                .font(.headline)
            HStack(spacing: 8) {
                Label(formattedDuration, systemImage: "clock")
                if !session.capturedApps.isEmpty {
                    Label(
                        session.capturedApps.map(\.displayName).joined(separator: ", "),
                        systemImage: "app"
                    )
                    .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                if session.transcriptFileName != nil {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.green)
                }
                if session.summaryFileName != nil {
                    Image(systemName: "text.badge.star")
                        .foregroundStyle(.blue)
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private var formattedDate: String {
        session.date.formatted(date: .abbreviated, time: .shortened)
    }

    private var formattedDuration: String {
        let mins = Int(session.duration) / 60
        let secs = Int(session.duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Session Detail

struct SessionDetailView: View {
    let session: Session
    var onDelete: () -> Void

    @State private var transcript: String = ""
    @State private var summary: String = ""
    @State private var isExporting = false
    @State private var exportResults: [ExportResult]?
    @State private var showExportResults = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.date.formatted(date: .long, time: .shortened))
                            .font(.title2)
                        HStack(spacing: 12) {
                            Label(formattedDuration, systemImage: "clock")
                            if !session.capturedApps.isEmpty {
                                Label(
                                    session.capturedApps.map(\.displayName).joined(separator: ", "),
                                    systemImage: "app"
                                )
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Summary
                if !summary.isEmpty {
                    GroupBox("Summary") {
                        Text(summary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Transcript
                if !transcript.isEmpty {
                    GroupBox("Transcript") {
                        Text(transcript)
                            .textSelection(.enabled)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if summary.isEmpty && transcript.isEmpty {
                    ContentUnavailableView(
                        "No Content",
                        systemImage: "doc",
                        description: Text("This session has no transcript or summary yet.")
                    )
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    let folder = SessionManager.shared.sessionFolder(for: session)
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
                } label: {
                    Image(systemName: "folder")
                }
                .help("Show in Finder")

                Button {
                    Task { await reExport() }
                } label: {
                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isExporting || (summary.isEmpty && transcript.isEmpty))
                .help("Re-export session")

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete session")
            }
        }
        .confirmationDialog(
            "Delete Session?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                try? SessionManager.shared.deleteSession(session)
                onDelete()
            }
        } message: {
            Text("Delete \"\(session.folderName)\" and all its files? This cannot be undone.")
        }
        .alert("Export Results", isPresented: $showExportResults) {
            Button("OK") {}
        } message: {
            if let results = exportResults {
                let lines = results.map { r in
                    r.success ? "\(r.exporter): OK" : "\(r.exporter): \(r.error ?? "Failed")"
                }
                Text(lines.joined(separator: "\n"))
            }
        }
        .onAppear { loadContent() }
        .onChange(of: session.id) { _, _ in loadContent() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loadContent()
        }
    }

    private var formattedDuration: String {
        let mins = Int(session.duration) / 60
        let secs = Int(session.duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func loadContent() {
        let folder = SessionManager.shared.sessionFolder(for: session)

        if let name = session.transcriptFileName {
            let url = folder.appendingPathComponent(name)
            transcript = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        } else {
            transcript = ""
        }
        if let name = session.summaryFileName {
            let url = folder.appendingPathComponent(name)
            summary = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        } else {
            summary = ""
        }
    }

    private func reExport() async {
        isExporting = true
        let results = await ExportOrchestrator.exportAll(
            session: session,
            summary: summary.isEmpty ? transcript : summary,
            transcript: transcript.isEmpty ? nil : transcript
        )
        exportResults = results
        isExporting = false
        showExportResults = true
    }
}

// MARK: - Hashable

extension Session: Hashable {
    static func == (lhs: Session, rhs: Session) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
