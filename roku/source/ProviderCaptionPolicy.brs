sub ApplyProviderCaption(content as object, session as object)
    if GetInterface(session.provider_caption,"ifAssociativeArray") = invalid then return
    caption = session.provider_caption
    language = lcase(Txt(caption.language))
    languages = {en:"eng",fr:"fre",de:"ger",es:"spa",it:"ita",ja:"jpn",pt:"por",nl:"dut",ar:"ara"}
    if languages.doesExist(language) then language = languages[language]
    content.SubtitleTracks = [{Language:language,Description:Txt(caption.label),TrackName:caption.url}]
    content.SubtitleConfig = {TrackName:caption.url}
end sub
