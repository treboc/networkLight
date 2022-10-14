//
//  networkLightApp.swift
//  networkLight
//
//  Created by Holger Krupp on 05.10.22.
//

import SwiftUI
import CoreData
import Combine
import Network

struct Speed{
    var id = UUID()
    var speed: Double?
    var unit: String?
    var date: Date?
    var icon: String?
}
struct SpeedLimit: Identifiable, Codable{

    
    var upperlimit: Double
    var lowerlimit: Double
    var icon: String
    var id = UUID()
    
    enum CodingKeys: CodingKey{
        case upperlimit, lowerlimit, icon, id
    }
    
    init(upperlimit: Double, lowerlimit: Double, icon: String){
        self.upperlimit = upperlimit
        self.lowerlimit = lowerlimit
        self.icon = icon
    }
    
    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self){
            self.upperlimit = try! container.decode(Double.self, forKey: .upperlimit)
            self.lowerlimit = try! container.decode(Double.self, forKey: .lowerlimit)
            self.icon = try! container.decode(String.self, forKey: .icon)
            self.id = UUID()
        }else{
            self.upperlimit = 0
            self.lowerlimit = 0
            self.icon = "🟣"
            self.id = UUID()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(upperlimit, forKey: .upperlimit)
        try container.encode(lowerlimit, forKey: .lowerlimit)
        try container.encode(icon, forKey: .icon)
        
    }
}

@main

struct networkLightApp: App {

    
    let persistenceController = PersistenceController.shared
    let viewContext = PersistenceController.shared.container.viewContext

    
    @State var Speeds = [String:Speed]()
    @State var running:Bool = false
   var SpeedLimits: Binding<[SpeedLimit]> { Binding(
        get: {if let limits = UserDefaults.standard.object(forKey: "SpeedLimits"){
            do {
                print("read Speedlimits")

                return try JSONDecoder().decode([SpeedLimit].self, from: limits as! Data)
            }catch{
                print("could not decode Speedlimits")
            }
        }
            return  [
                SpeedLimit(upperlimit: 100.0,lowerlimit: 70.0,icon: "🟢"),
                SpeedLimit(upperlimit: 70.0,lowerlimit: 20.0,icon: "🟡"),
                SpeedLimit(upperlimit: 20.0,lowerlimit: 0.0,icon: "🔴")
            ]
        
            
        },
        set: {limit in
            dump(limit)
            
            do{
                let JSON = try JSONEncoder().encode(limit)
                UserDefaults.standard.set(JSON, forKey: "SpeedLimits")
                
            }catch{
                print("could not save Speedlimits to UserDefaults")
            }
        }
    )
        
    }
    
    
    @State var timer:Timer? = nil
    @State var timerrunning:Bool = false
    
    @State var maxDownload = UserDefaults.standard.object(forKey: "maxDownload") as? Double ?? 100.0
    @State var maxUpload = UserDefaults.standard.object(forKey: "maxUpload") as? Double ?? 20.0

    @State var repleattime = UserDefaults.standard.object(forKey: "repleattime") as? Int ?? 600 {
        willSet{
            UserDefaults.standard.set(repleattime, forKey: "repleattime")
        }
    }

    var maxSpeeds:[String:Speed] = [
        "Download":Speed(id: UUID(), speed: 100, unit: "Mbps", date: Date(), icon: nil),
        "Upload":Speed(id: UUID(), speed: 30, unit: "Mbps", date: Date(), icon: nil)
    ]
    
 
    
    var body: some Scene {
   
        WindowGroup("NetworkLight") {
            VStack{
                Text("Warning").bold()
                Text("For debugging purpose only")
                Text("This App might slow down your Network traffic. Please verify with other users on your network the usage of this app.")
//                Button("Understood") {
//                    //NSApplication.shared.keyWindow?.close()
//                    NSApplication.shared.mainWindow?.close()
//                }
            }
        }.handlesExternalEvents(matching: Set(arrayLiteral: "NetworkLight"))
        
            WindowGroup("Settings") {
                SettingsView( SpeedLimits: SpeedLimits, repleattime: $repleattime)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    

            }.handlesExternalEvents(matching: Set(arrayLiteral: "SettingsWindow"))
        
        WindowGroup("History") {
            HistoryView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .frame(width: 300, height: 800)
                .frame(minWidth: 300, maxWidth: .infinity,
                       minHeight: 600, maxHeight: .infinity)
        }.handlesExternalEvents(matching: Set(arrayLiteral: "HistoryWindow"))
        
        MenuBarExtra {
           
            Group{
              
                if let upload = Speeds["Upload"]{
                    if let speed =  upload.speed{
                        Text("\(upload.icon ?? "") Upload: \(String(format: "%.0f",speed)) \(upload.unit ?? "Mbps")")
                        
                    }
                }
                if let download = Speeds["Download"]{
                    if let speed =  download.speed{
                        Text("\(download.icon ?? "") Download: \(String(format: "%.0f",speed)) \(download.unit ?? "Mbps")")
                        Text("Last Test: \(download.date?.formatted() ?? "unknown")")
                    }
                }
                Divider()
            }
            if running == false {
                Button("Run Now") {
                    Task{
                        await readNetworkStatus()
                    }
                }.keyboardShortcut("N")
            }else{
                Text("running")
            }
            
            if (timerrunning == true){
                let nextrun = timer?.fireDate.formatted(date: .omitted, time: .shortened)
                Button("Stop autorun - next: \(nextrun ?? "-")"){
                    stopTimer()
                }
            }else{
                
                Button("Autorun every \(String(repleattime/60)) Minutes"){
                    startTimer()
                }
                
            }
            

            
            Button("Settings") {
                OpenWindows.Settingsview.open()
            }.keyboardShortcut(",")
            
            Button("History") {
                OpenWindows.Historyview.open()
            }.keyboardShortcut("H")
            
            
            
            
            
            
            
            
            Divider()
            
            
            
            Button("Quit") {
                timer?.invalidate()
                NSApplication.shared.terminate(nil)
                
            }.keyboardShortcut("q")
//
//            HistoryView()
//                .environment(\.managedObjectContext, persistenceController.container.viewContext)

            
        }label: {
            
            if true { // there should be a check if network is available, but all solutions block the UI.

                if running == true {
                    Text("🔘")
                    
                }else{
                    
                    Text(Speeds["Download"]?.icon?.description ?? "⚪️")
                        .onAppear(){
                        Task{
                                //readSpeedLimits()
                            
                        }
                    }
                    
                }
                
            }else{
                // no network available
                Text("⚫️").onAppear(){
                    
                    Speeds["Download"]?.speed = 0.0
                    Speeds["Upload"]?.speed = 0.0
                    Speeds["Download"]?.date = Date()
                    Speeds["Upload"]?.date = Date()
                    addItem()

                }
            }
        }
        
    }
    
    enum OpenWindows: String, CaseIterable {
        case Settingsview = "SettingsWindow"
        case Historyview = "HistoryWindow"
        //As many views as you need.
        
        func open(){
//            repleattime = UserDefaults.standard.object(forKey: "repleattime") as? Int ?? 600
            if let url = URL(string: "networkLight://\(self.rawValue)") { //replace myapp with your app's name
                NSWorkspace.shared.open(url)
            }
        }
    }

    
     func startTimer(){
         timerrunning = true
         timer = Timer.init(timeInterval: TimeInterval(repleattime), repeats: true, block: { timer in
                Task{
                    await readNetworkStatus()
                }
            })
            RunLoop.current.add(timer!, forMode: RunLoop.Mode.common)
         timer?.fire()
    }
    
    
     func stopTimer(){
         timerrunning = false
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }
    


    func readNetworkStatus() async{
        print("reading NetworkStatus")
        maxDownload = UserDefaults.standard.object(forKey: "maxDownload") as? Double ?? 100.0
        maxUpload = UserDefaults.standard.object(forKey: "maxUpload") as? Double ?? 20.0
        print("maxDownload: \(maxDownload.description) - maxUpload: \(maxUpload.description)")
        running = true
        do {
            try await networkquality()
            addItem()
            running = false
        } catch {
            running = false
        }
    }
    
    private func addItem() {
        withAnimation {
            let newSpeedLog = SpeedLog(context: viewContext)
            if let download = Speeds["Download"]?.speed{
                newSpeedLog.download = download
            }
            if let upload = Speeds["Upload"]?.speed{
                newSpeedLog.upload = upload
            }
            if let date = Speeds["Upload"]?.date{
                newSpeedLog.date = date
            }

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func networkquality() async throws{
        print("networkquality")
        // there is the option to use "networkquality -c" which creates machine readable output (JSON). Unfortunatly Mbps has to be calculated manually from the data provided and I don't know how to do that. Therefore I scrap the output of the human readable format until I found a solution.
        
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", "networkquality"]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.standardInput = nil
        
        try task.run()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        
        let UploadKeyword = "Uplink capacity: "
        let DownloadKeyword = "\nDownlink capacity: "
        let ResponsivenessKeyword = "\nResponsiveness: "
   //     let EndKeyword = "\nIdle Latency:"
        let now = Date()
        
        if let UploadRangeStart = output.range(of: UploadKeyword)?.upperBound, let UploadRangeEnd = output.range(of: DownloadKeyword)?.lowerBound{
            
            let UploadRange = Range(uncheckedBounds: (lower: UploadRangeStart, upper: UploadRangeEnd))
            
            let UploadComponents = output[UploadRange].components(separatedBy: " ")
            
            var Upload = Speed(speed: Double(UploadComponents[0]), unit: UploadComponents[1], date: now)
            if let speed = Upload.speed{
                let ratio = speed/maxUpload*100
                if ratio > 100{
                    Upload.icon = SpeedLimits.first?.icon.wrappedValue
                }else{
                    let limit = SpeedLimits.filter { $0.upperlimit.wrappedValue > ratio && $0.lowerlimit.wrappedValue < ratio}
                    Upload.icon = limit.first?.icon.wrappedValue
                }
            }
            Speeds.updateValue(Upload, forKey: "Upload")
        }
        
        if let DownloadRangeStart = output.range(of: DownloadKeyword)?.upperBound, let DownloadRangeEnd = output.range(of: ResponsivenessKeyword)?.lowerBound {
            let DownloadRange = Range(uncheckedBounds: (lower: DownloadRangeStart, upper: DownloadRangeEnd))
            
            let DownloadComponents = output[DownloadRange].components(separatedBy: " ")
            var Download = Speed(speed: Double(DownloadComponents[0]), unit: DownloadComponents[1], date: now)

            
            
            if let speed = Download.speed{
                let ratio = speed/maxDownload*100
                if ratio > 100{
                    Download.icon = SpeedLimits.first?.icon.wrappedValue
                }else{
                    let limit = SpeedLimits.filter { $0.upperlimit.wrappedValue ?? 0.0 > ratio && $0.lowerlimit.wrappedValue ?? 0.0 < ratio}
                    Download.icon = limit.first?.icon.wrappedValue
                }


            }
            Speeds.updateValue(Download, forKey: "Download")
            
        }

    }
    
    
    

    
    
    
}
