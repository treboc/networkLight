//
//  HistoryView.swift
//  networkLight
//
//  Created by Holger Krupp on 05.10.22.
//

import SwiftUI
import CoreData
import Foundation
import Charts



struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext



    @FetchRequest (
        entity: ContentView_Previews.entity,
        sortDescriptors: [NSSortDescriptor(keyPath: \SpeedLog.date, ascending: false)],
        animation: .default
    ) var SpeedLogs: FetchedResults<SpeedLog>

    @State  var Speeds = [String:Speed]()
//
//    @State var baseDownload = "1000"
//    @State var baseUpload = "100"
//
    //View definition
    @State var compact: Bool
    @State private var viewType = 0
    @State private var source = 0
    
    @State var limits: [SpeedLimit]? = nil
    @State var refresh: Bool = false

    var body: some View {
        VStack{
            
            
            if compact{
                ForEach(SpeedLogs.prefix(3)){ speedlog in
                    Divider()
                    
                    Text(speedlog.date?.formatted() ?? "--").frame(maxWidth: .infinity, alignment: .center)
                    
                    VStack{
                        Text("Upload: \(String(format: "%.0f",speedlog.upload)) Mbps").frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Download: \(String(format: "%.0f",speedlog.download)) Mbps").frame(maxWidth: .infinity, alignment: .trailing)

                    }.frame(maxWidth: .infinity, alignment: .trailing)
                }
            }else{
                VStack{                    
                    Picker("Display ", selection: $viewType) {
                        Text("Table").tag(0)
                        Text("Chart").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    if viewType == 0{
                        Table {
                            TableColumn("Date") {speedlog in
                                Text(speedlog.date?.formatted() ?? "--")
                            }
                            TableColumn("Upload") {speedlog in
                                Text("\(String(format: "%.0f",speedlog.upload)) Mbps").frame(maxWidth: .infinity, alignment: .trailing)
                                
                            }.width(150)
                            TableColumn("Download") {speedlog in
                                
                                Text("\(String(format: "%.0f",speedlog.download)) Mbps").frame(maxWidth: .infinity, alignment: .trailing)
                                
                            }.width(150)
                        } rows: {
                            ForEach(SpeedLogs.prefix(30)){ speedlog in
                                TableRow(speedlog)
                            }
                        }
                        
                    }else{
                        VStack{
                            Picker("", selection: $source) {
                                Text("Download").tag(0)
                                Text("Upload").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .padding()
                            
                            Chart{
                                ForEach(SpeedLogs) { speedlog in
                                    if source == 0{
                                        PointMark(
                                            x: .value("Date", speedlog.date ?? Date()),
                                            y: .value("Download Speed", speedlog.download)
                                        )
                                    }else{
                                        PointMark(
                                            x: .value("Date", speedlog.date ?? Date()),
                                            y: .value("Upload Speed", speedlog.upload)
                                        )
                                    }
                                    
                                }
                            }.padding()
                            
                                .foregroundColor(Color.blue)
                                .chartPlotStyle { plotContent in
                                    plotContent
                                        .background(.white.opacity(0.4))
                                    
                                }
                        }
                        
                    }
                    
                    
                    Button("Export SpeedLogs"){
                        ExportCSV()
                    }.keyboardShortcut("S")
                    Button("Delete SpeedLogs"){
                        deleteall()
                    }
                }.padding()
                    .frame(minWidth: 500, idealWidth: 500, maxWidth: .infinity, minHeight: 400, idealHeight: 400, maxHeight: .infinity, alignment: .center)

            }


        }
    }
    
    func ExportCSV(){
        
        
        let headerString: String = "Date (IS8601), Date, Upload (Mbps), Download (Mbps)"
        
        
        var exportString: String = ""
        exportString.append(headerString)
        exportString.append("\n")
        
        for speedlog in SpeedLogs {
            
            let exportLine = "\"\(speedlog.date?.ISO8601Format().description ?? "")\",\" \(speedlog.date?.formatted() ?? "")\", \(String(format: "%.0f",speedlog.upload)), \(String(format: "%.0f",speedlog.download))"
            
            
            exportString.append(exportLine)
            exportString.append("\n")
            
            
        }
        
        if let saveURL = showSavePanel(){
            do {
                try exportString.write(to: saveURL, atomically: true, encoding: .utf8)
            }catch{
                print("error creating file")

            }
        }

        }
        
    
    func deleteall(){
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "SpeedLog")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(deleteRequest)
            
            self.refresh.toggle()
        } catch let error as NSError {
            // TODO: handle the error
        }
    }
    
    func showSavePanel() -> URL? {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.allowsOtherFileTypes = false
        savePanel.title = "Save your data"
        savePanel.message = "Choose a folder and a name to store your results."
        savePanel.nameFieldLabel = "File name:"
        savePanel.nameFieldStringValue = "NetworkLightExport.csv"
        
        let response = savePanel.runModal()
        return response == .OK ? savePanel.url : nil
    }



    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { SpeedLogs[$0] }.forEach(viewContext.delete)

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
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var entity: NSEntityDescription {
        return NSEntityDescription.entity(forEntityName: "SpeedLog", in: PersistenceController.preview.container.viewContext)!
    }
    static var previews: some View {
        HistoryView(compact: false).environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

