import SwiftUI
import CoreLocation

struct GymLocationsView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var label: String = ""
    @State private var address: String = ""
    @State private var latitude: String = ""
    @State private var longitude: String = ""
    @State private var radius: Double = 150

    var body: some View {
        Form {
            Section("Saved gyms") {
                ForEach(store.gymLocations) { gym in
                    VStack(alignment: .leading) {
                        Text(gym.label)
                            .font(.headline)
                        Text(gym.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Radius: \(Int(gym.radius)) m")
                            .font(.caption2)
                    }
                }
            }

            Section("Add gym") {
                TextField("Label", text: $label)
                TextField("Address", text: $address)
                TextField("Latitude", text: $latitude)
                    .keyboardType(.decimalPad)
                TextField("Longitude", text: $longitude)
                    .keyboardType(.decimalPad)
                Slider(value: $radius, in: 50...500, step: 10) {
                    Text("Radius")
                }
                Text("\(Int(radius)) meters")
                Button("Save gym") {
                    let coord = CLLocationCoordinate2D(latitude: Double(latitude) ?? 0, longitude: Double(longitude) ?? 0)
                    store.addGymLocation(label: label, address: address, coordinate: coord, radius: radius)
                    label = ""; address = ""; latitude = ""; longitude = ""; radius = 150
                }
                .disabled(label.isEmpty || address.isEmpty)
            }
        }
        .navigationTitle("Gyms")
    }
}
