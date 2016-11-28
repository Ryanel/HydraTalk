this.hydra = {} unless this.hydra?
hydra = this.hydra

# Define UI constants

conversationlist = "#conversation-list"
chat = "chat-messages"

appbar_sendmessage = "#appbar-sendmessage"
appbar_input = "#appbar-input"
appbar_menu = "#appbar-menu"
appbar_menu_content = "#appbar-menu-content"
appbar_username = "#appbar-username"
appbar_avatar = "#appbar-useravatar"

class UI
    constructor: ->
        @isSetup = false
        @currentConversation = null
        debug.debug("UI","Created")

    start: ->
        @isSetup = true if localStorage["setupComplete"] is "true"
        @setupSignals()
        @refresh()
        @setupNativeUI() if config.clientInfo.isElectron
        @showSetupDialog() if not @isSetup
        debug.debug("UI","Starting")

    refresh: ->
        @updateConversationList()
        @updateAppbarUserInfo()
        @displayConversation(@currentConversation) if @currentConversation?
        debug.debug("UI","Refreshing")

    setupNativeUI: ->
        debug.log("UI", "Native app, modifying UI accordingly")

    setupSignals: ->
        $(conversationlist).on("click", ".conversation-base", @signalConversationClicked)
        $(appbar_sendmessage).click(@signalMessageSent)
        $(appbar_input).keyup((event) ->
            $(appbar_sendmessage).click() if event.keyCode is 13
        )
        $(appbar_menu).click(@signalMenuClick)
        $(appbar_menu_content).on("click", "li", @signalMenuItemClick)
        return true

    updateConversationList: ->
        conversations =  hydra.database.conversations.conversations.length
        return $(conversationlist).html("<div id='noconversationtext'>No Conversations</div>") if conversations is 0
        # Order the list
        conversations_sorted = hydra.database.conversations.conversations.sort((a, b) ->
            return b.startDate - a.startDate # HACK: Implement from time last message sent
        )
        $(conversationlist).html("")
        for i in conversations_sorted
            partner = hydra.database.people.findById(i.partner)
            last_message = i.getLastMessage()
            if last_message?
                display_text = "You:" if last_message.status > 0
                display_text = "System: " if last_message.status is 0
                display_text = "#{partner.name}: " if last_message.status < 0
                display_text += last_message.content
                time = last_message.time
            else
                display_text = ""
                time = 0
            element = @createConversationElement(i.partner,display_text,time)
            continue if element is null
            $(element).addClass("conversation-base-selected") if @currentConversation is i
            $(conversationlist).append(element)
        return

    updateAppbarUserInfo: ->
        return unless hydra.userInfo.user?
        $(appbar_avatar).attr("src", hydra.userInfo.user.avatar_location)
        $(appbar_username).text(hydra.userInfo.user.name)

    displayConversation: (conversation) ->
        $(chat).html("")
        return unless conversation?
        for message in conversation.messages
            $(chat).append(hydra.ui.createMessageElement(message))
        @scrollChatBottom()

    signalMenuClick: (event) ->
        $(appbar_menu_content).toggle()

    signalMenuItemClick: (event) ->
        $(appbar_menu_content).hide()
        clicked = $(this).attr("data-uri")

    signalMessageSent: (event) =>
        content = $(appbar_input).val()
        return if @currentConversation is null or content is ""
        message = new hydra.Message(content, 1, "text", Date.now(), 0)
        @currentConversation.addMessage(message)
        hydra.dispatch.sendMessage(@currentConversation.partner, message, @currentConversation.providers[0])
        hydra.database.conversations.save()
        hydra.ui.refresh()
        hydra.ui.scrollChatBottom()
        $(appbar_input).val("") # Clear out input field

    signalConversationClicked: (event) ->
        person_id = Number($(this).attr("person_id"))
        return if person_id is 0
        newConversation = hydra.database.conversations.getFromPID(person_id)
        hydra.ui.currentConversation = newConversation unless newConversation is null
        hydra.ui.refresh()
        hydra.ui.scrollChatBottom() unless newConversation is null

    scrollChatBottom: ->
        $(chat).scrollTop($(chat)[0].scrollHeight)

    showSetupDialog: ->
        $("#setup-dialog").show()
        $("#setup-dialog-confirm").click(() ->
            $("#setup-dialog").hide()
            hydra.currentUser.user.name = $("#setup-name").val()
            hydra.currentUser.user.avatar_location = $("#setup-avatar").val()
            hydra.currentUser.save()
            localStorage["setupComplete"] = "true"
            @isSetup = true
            @updateAppbarUserInfo()
        )

    showWarningDialog: ->

    createMessageElement: (message) ->
        return null unless message?
        element = $("<div>").addClass("chat-message")
        $(element).addClass("chat-message-partner") if message.status < 0
        $(element).addClass("chat-message-user") if message.status > 0
        $(element).addClass("chat-message-system") if message.status is 0
        switch message.content_type
            when "image"
                message_image = $("<img>").addClass("chat-message-image")
                message_image.attr("src", message.content)
                element.append(message_image)
            when "text"
                element.append($("<span>#{message.content}</span>"))
        return element

    createConversationElement: (person_id, text, time) ->
        person = hydra.database.people.findById(person_id)
        return null if person is null
        element = $("<div>").addClass("conversation-base")
            .attr("person_id", person_id)
        icon = $("<img>").addClass("conversation-icon")
            .attr("src", person.avatar_location)
        provider_icon = $("<img>").addClass("provider-icon")
            .attr("src", person.avatar_location)
        name = $("<div>").addClass("conversation-name").text(person.name)
        time = $("<div>").addClass("conversation-time").text(time)
        blurb = $("<div>").addClass("conversation-blurb").text(text)
        element.append(icon, name, time, blurb, provider_icon)
        return element

hydra.ui = new UI()
