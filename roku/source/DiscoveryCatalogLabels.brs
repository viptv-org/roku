function DiscoveryCatalogLabels(catalogs as object) as object
    counts = {}
    for each catalog in catalogs
        name = Txt(catalog.name,Txt(catalog.id))
        if not counts.doesExist(name) then counts[name] = 0
        counts[name]++
    end for
    labels = []
    duplicates = {}
    for each catalog in catalogs
        name = Txt(catalog.name,Txt(catalog.id))
        if counts[name] > 1 and Txt(catalog.addon_name) <> "" then name = Txt(catalog.addon_name)+" · "+name
        labels.push(name)
        if not duplicates.doesExist(name) then duplicates[name] = 0
        duplicates[name]++
    end for
    seen = {}
    for i = 0 to labels.count()-1
        name = labels[i]
        if duplicates[name] > 1
            if not seen.doesExist(name) then seen[name] = 0
            seen[name]++
            labels[i] = name+" ("+seen[name].toStr()+")"
        end if
    end for
    return labels
end function
