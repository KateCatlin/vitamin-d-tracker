import SwiftUI
import VitaminDTrackerCore

/// Settings and profile screen.
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                // Location section
                Section {
                    HStack {
                        Label("My City", systemImage: "location.fill")
                        Spacer()
                        Text(viewModel.userProfile.homeLocation?.displayName ?? "Not set")
                            .foregroundColor(.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.showCitySheet = true }
                } header: {
                    Text("Location")
                }

                // Skin type section
                Section {
                    HStack {
                        Label("Skin Type", systemImage: "hand.raised.fill")
                        Spacer()
                        Text(viewModel.skinTypeDisplayText)
                            .foregroundColor(.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.showSkinTypeSheet = true }
                } header: {
                    Text("Fitzpatrick Skin Type")
                } footer: {
                    Text("Affects sunburn risk thresholds and estimated vitamin D production from sun exposure.")
                }

                // Lab test section
                Section {
                    Button {
                        viewModel.showTestResultSheet = true
                    } label: {
                        Label("Enter New Test Result", systemImage: "cross.case.fill")
                    }
                } header: {
                    Text("Vitamin D Test")
                } footer: {
                    Text("A new lab result will become the trusted anchor for future estimates.")
                }

                // Supplement section
                Section {
                    HStack {
                        Label("Current Supplement", systemImage: "pills.fill")
                        Spacer()
                        Text(viewModel.supplementDisplayText)
                            .foregroundColor(.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.showSupplementSheet = true }
                } header: {
                    Text("Supplement")
                } footer: {
                    Text("Changes apply from today forward. Historical estimates are not recalculated.")
                }

                // Model section
                Section {
                    Button {
                        viewModel.showModelAssumptions = true
                    } label: {
                        Label("View Model Assumptions", systemImage: "function")
                    }
                } header: {
                    Text("Science")
                }

                // Disclaimer section
                Section {
                    Button {
                        viewModel.showDisclaimer = true
                    } label: {
                        Label("View Disclaimer", systemImage: "exclamationmark.triangle.fill")
                    }

                    if let date = viewModel.userProfile.disclaimerAcceptedDate {
                        HStack {
                            Text("Accepted")
                                .foregroundColor(.textSecondary)
                            Spacer()
                            Text(date, style: .date)
                                .foregroundColor(.textSecondary)
                                .font(.system(size: 14))
                        }
                    }
                } header: {
                    Text("Disclaimer")
                }

                // About section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.textSecondary)
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Vitamin D Tracker provides estimates only. This is not medical advice. Consult a healthcare provider for vitamin D testing and supplementation guidance.")
                        .font(.system(size: 12))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { viewModel.loadData() }

            // MARK: - Sheets

            .sheet(isPresented: $viewModel.showCitySheet) {
                CityPickerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showSkinTypeSheet) {
                SkinTypePickerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showTestResultSheet) {
                TestResultSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showSupplementSheet) {
                SupplementSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showModelAssumptions) {
                ModelAssumptionsSheet()
            }
            .sheet(isPresented: $viewModel.showDisclaimer) {
                DisclaimerSheet()
            }
        }
    }
}

// MARK: - Skin Type Picker Sheet

struct SkinTypePickerSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List(FitzpatrickSkinType.allCases, id: \.rawValue) { skinType in
                Button {
                    viewModel.updateSkinType(skinType)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(skinType.displayColor)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().stroke(Color.subtleDivider, lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(skinType.displayName)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.textPrimary)
                            Text(skinType.sunResponse)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        if viewModel.userProfile.skinType == skinType {
                            Image(systemName: "checkmark")
                                .foregroundColor(.sunOrange)
                        }
                    }
                }
            }
            .navigationTitle("Skin Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - City Picker Sheet

struct CityPickerSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.textSecondary)
                    TextField("Search cities or countries...", text: $viewModel.citySearchText)
                }
                .padding(12)
                .background(Color.skyBlueLight)
                .cornerRadius(12)
                .padding(.horizontal, 16)

                List {
                    // Recent cities section
                    if !viewModel.recentCities.isEmpty && viewModel.citySearchText.isEmpty {
                        Section("Recent") {
                            ForEach(viewModel.recentCities, id: \.cityName) { city in
                                Button {
                                    viewModel.updateCity(city)
                                    dismiss()
                                } label: {
                                    CityPickerRow(
                                        city: city,
                                        isSelected: viewModel.userProfile.homeLocation?.cityName == city.cityName
                                    )
                                }
                            }
                        }
                    }

                    // All cities section
                    Section(viewModel.citySearchText.isEmpty ? "All Cities" : "Results") {
                        ForEach(viewModel.filteredCities, id: \.cityName) { city in
                            Button {
                                viewModel.updateCity(city)
                                dismiss()
                            } label: {
                                CityPickerRow(
                                    city: city,
                                    isSelected: viewModel.userProfile.homeLocation?.cityName == city.cityName
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct CityPickerRow: View {
    let city: HomeLocation
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(city.cityName)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.textPrimary)
                if !city.country.isEmpty {
                    Text(city.country)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.textSecondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.sunOrange)
            }
        }
    }
}

// MARK: - Test Result Sheet

struct TestResultSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Test Value") {
                    TextField("Value", text: $viewModel.newTestValue)
                        .keyboardType(.decimalPad)

                    Picker("Unit", selection: $viewModel.newTestUnit) {
                        ForEach(VitaminDUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                }

                Section("Test Date") {
                    DatePicker(
                        "Date",
                        selection: $viewModel.newTestDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }

                Section {
                    Button("Save") {
                        viewModel.saveNewTestResult()
                        dismiss()
                    }
                    .disabled(Double(viewModel.newTestValue) == nil)
                }
            }
            .navigationTitle("New Test Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Supplement Sheet

struct SupplementSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily Dose") {
                    TextField("IU per day", text: $viewModel.newDoseText)
                        .keyboardType(.numberPad)
                }

                Section("Type") {
                    Picker("Vitamin D Type", selection: $viewModel.newVitaminDType) {
                        ForEach(VitaminDType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    Button("Save") {
                        viewModel.saveNewSupplement()
                        dismiss()
                    }
                } footer: {
                    Text("This change takes effect from today. Historical estimates will not change.")
                }
            }
            .navigationTitle("Update Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Model Assumptions Sheet

struct ModelAssumptionsSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(ModelingAssumptions.summary)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.textPrimary)
                        .padding()

                    Text("See MODELING.md in the repository for full scientific references and methodology.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal)
                }
            }
            .navigationTitle("Model Assumptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Disclaimer Sheet

struct DisclaimerSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("⚠️ Medical Disclaimer")
                            .font(.system(size: 20, weight: .bold, design: .rounded))

                        Text("This app provides rough estimates only. It is NOT medical advice.")
                        Text("This app is NOT for diagnosis or treatment of any condition.")
                        Text("The vitamin D estimates are based on simplified scientific models with significant uncertainty.")
                        Text("Always consult a qualified healthcare provider for:")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Interpretation of vitamin D blood test results")
                            Text("• Vitamin D supplementation advice")
                            Text("• Sun exposure and skin cancer risk guidance")
                            Text("• Any health concerns related to vitamin D")
                        }

                        Text("Do not rely on this app for any medical decisions.")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.textPrimary)
                }
                .padding()
            }
            .navigationTitle("Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
