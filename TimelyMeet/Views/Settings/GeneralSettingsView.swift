//
//  GeneralSettingsView.swift
//  TimelyMeet
//
//
//

import SwiftUI
import ServiceManagement
import os.log

struct GeneralSettingsView: View {
    @State private var launchAtLogin = false
    @State private var showApprovalAlert = false

    private let logger = Logger(subsystem: "org.romancha.timelymeet", category: "GeneralSettings")

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("settings_general".localized())
                .font(.title2)
                .fontWeight(.bold)

            Text("general_settings_description".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 20) {
                // Launch at Login Settings
                GroupBox("startup_behavior".localized()) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $launchAtLogin) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("launch_at_login".localized())
                                    .font(.headline)
                                Text("launch_at_login_description".localized())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { _, newValue in
                            handleLaunchAtLoginChange(newValue)
                        }

                        if showApprovalAlert {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("approval_required".localized())
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text("approval_required_description".localized())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer()
        }
        .onAppear {
            syncLaunchAtLoginState()
        }
    }

    // MARK: - Private Methods

    private func syncLaunchAtLoginState() {
        let status = SMAppService.mainApp.status
        logger.debug("SMAppService status: \(String(describing: status))")

        switch status {
        case .enabled:
            launchAtLogin = true
            showApprovalAlert = false
        case .requiresApproval:
            launchAtLogin = true
            showApprovalAlert = true
        default:
            launchAtLogin = false
            showApprovalAlert = false
        }
    }

    private func handleLaunchAtLoginChange(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                logger.info("Successfully registered app for launch at login")

                // Re-check status after registration
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    syncLaunchAtLoginState()
                }
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Successfully unregistered app from launch at login")
                showApprovalAlert = false
            }
        } catch {
            logger.error("Failed to \(enabled ? "register" : "unregister") launch at login: \(error.localizedDescription)")

            // Revert the toggle state on error
            DispatchQueue.main.async {
                launchAtLogin = !enabled
            }
        }
    }
}

#Preview {
    GeneralSettingsView()
}
