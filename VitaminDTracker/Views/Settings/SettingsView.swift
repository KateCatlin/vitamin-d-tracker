import SwiftUI

/// Settings and profile screen.
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                // Location section
                Section {
                    HStack {
                        Label("Home City", systemImage: "location.fill")
                        Spacer()
                        Text(viewModel.userProfile.homeLocation?.cityName ?? "Not set")
                            .foregroundColor(.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.showCitySheet = true }
                } header: {
                    Text("Location")
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
                    TextField("Search cities...", text: $viewModel.citySearchText)
                }
                .padding(12)
                .background(Color.skyBlueLight)
                .cornerRadius(12)
                .padding(.horizontal, 16)

                List(viewModel.filteredCities, id: \.cityName) { city in
                    Button {
                        viewModel.updateCity(city)
                        dismiss()
                    } label: {
                        HStack {
                            Text(city.cityName)
                            Spacer()
                            if viewModel.userProfile.homeLocation?.cityName == city.cityName {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.sunOrange)
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
