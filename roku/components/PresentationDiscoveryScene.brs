sub uiDiscoverFilters()
    if m.discoverFilters = invalid then return
    typeRoot = CreateObject("roSGNode","ContentNode")
    m.discoverTypeItems = Bounded(m.discoverMediaTypes,64)
    for each kind in m.discoverTypeItems
        node = typeRoot.createChild("ContentNode")
        node.title = DiscoveryTypeLabel(kind)
        node.addFields({uiWidth:146,selected:m.discoverType = kind,dropdown:false,uiOwnerFocused:false})
    end for
    m.discoverTypes.content = typeRoot
    m.discoverTypes.visible = m.mode = "browse" and m.discoverActive = true
    values = []
    labels = DiscoveryCatalogLabels(m.discoverCatalogs)
    for i = 0 to m.discoverCatalogs.count()-1
        catalog = m.discoverCatalogs[i]
        chosen = false
        if m.catalog <> invalid then chosen = Txt(catalog.id) = Txt(m.catalog.id) and Txt(catalog.connection_id) = Txt(m.catalog.connection_id) and Txt(catalog.type) = Txt(m.catalog.type)
        values.push({name:labels[i],action:"catalog",catalogIndex:i,selected:chosen})
    end for
    if m.catalog <> invalid
        for each control in Bounded(m.catalog.controls,64)
            if control.id <> "type" and control.id <> "catalog" and control.id <> "skip" and control.maximum_selections <> 0
                currentValues = DiscoveryControlValues(control,m.search,m.discoverGenre,m.discoverExtras,m.discoverVectors)
                label = Txt(control.label,control.id)+": "+DiscoveryControlLabel(control,currentValues)
                values.push({name:label,action:"dcontrol",control:control,selected:currentValues.count() > 0})
            end if
        end for
    end if
    m.discoverFilterItems = values
    root = CreateObject("roSGNode","ContentNode")
    for each value in values
        node = root.createChild("ContentNode")
        node.title = value.name
        node.addFields({selected:value.selected,dropdown:value.action <> "catalog",uiOwnerFocused:false})
    end for
    prior = RestoreCardIndex(m.discoverFilters.itemFocused,values.count())
    m.discoverFilters.content = root
    m.discoverFilters.jumpToItem = prior
    m.discoverFilters.visible = m.mode = "browse" and m.discoverActive = true
end sub

sub uiDiscoverFilterSelected()
    index = m.discoverFilters.itemSelected
    if index < 0 or index >= m.discoverFilterItems.count() then return
    item = m.discoverFilterItems[index]
    if item.action = "catalog"
        m.catalog = m.discoverCatalogs[item.catalogIndex]
        uiRequiredGenre()
        browse(m.discoverType,0)
    else if item.action = "dcontrol"
        uiDiscoveryControl(item.control)
    end if
end sub

sub uiDiscoveryControl(control as object)
    m.discoverExtraName = control.id
    currentValues = DiscoveryControlValues(control,m.search,m.discoverGenre,m.discoverExtras,m.discoverVectors)
    if control.kind = "Toggle"
        value = "true"
        if currentValues.count() > 0 and currentValues[0] = "true" then value = "false"
        uiSetDiscoveryScalar(control.id,value)
        browse(m.discoverType,0)
        return
    end if
    values = []
    index = 0
    if control.kind <> "MultiChoice" and control.required <> true then values.push({name:"Default",value:""})
    for each choice in Bounded(control.choices,2048)
        if currentValues.count() > 0 and currentValues[0] = Txt(choice.value) then index = values.count()
        values.push({name:Txt(choice.label,Txt(choice.value)),value:Txt(choice.value)})
    end for
    if Bounded(control.choices,2048).count() = 0
        value = ""
        if currentValues.count() > 0 then value = currentValues[0]
        keyboard("discoverExtra",Txt(control.label,control.id),value)
    else
        m.choiceKind = "discoverControl"
        m.choiceGeneration = m.generation
        m.choicePanel.model = {title:Txt(control.label,control.id),items:values,index:index,multiple:control.kind = "MultiChoice",selected:currentValues,maximum:control.maximum_selections,required:control.required}
    end if
end sub

sub uiSetDiscoveryScalar(name as string, value as string)
    if name = "search"
        m.search = value
    else if name = "genre"
        m.discoverGenre = value
    else
        m.discoverExtras[name] = value
    end if
end sub
