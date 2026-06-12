package func shouldPetPanelIgnoreMouseEvents(
    insideVisibleSprite: Bool,
    interactionActive: Bool,
    contextMenuOpen: Bool
) -> Bool {
    !(insideVisibleSprite || interactionActive || contextMenuOpen)
}
