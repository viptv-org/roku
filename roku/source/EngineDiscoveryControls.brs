function EngineDiscoveryControls(data as dynamic, kind as string) as dynamic
    if not AccountIsObject(data) then return invalid
    if not EngineIsArray(data.media_types) or not EngineIsArray(data.catalogs) then return invalid
    if not EngineIsArray(data.controls) or not AccountIsObject(data.discovery) then return invalid
    output = {catalogs:[],media_types:[],availability:Txt(data.discovery.availability),message:Txt(data.discovery.message)}
    for each value in Bounded(data.media_types,64)
        if Txt(value) <> "" and Txt(value) <> "live" then output.media_types.push(Txt(value))
    end for
    if output.availability <> "Available" then return output
    for each catalog in Bounded(data.catalogs,2048)
        if AccountIsObject(catalog) and Txt(catalog.type) = kind and EngineIsArray(catalog.controls)
            if Txt(catalog.connection_id) <> ""
                output.catalogs.push({id:Txt(catalog.id),name:Txt(catalog.name),type:kind,connection_id:Txt(catalog.connection_id),addon_id:catalog.addon_id,addon_name:Txt(catalog.connection_name),controls:catalog.controls,extra:[],genres:[]})
            end if
        end if
    end for
    if data.catalogs.count() = 0
        for each value in output.media_types
            if value = kind
                output.catalogs.push({id:"",name:"All titles",type:kind,connection_id:Txt(data.provider_id),controls:data.controls,extra:[],genres:[]})
                exit for
            end if
        end for
    end if
    return output
end function

