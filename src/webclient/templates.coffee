

TAB_SYSTEM = '
    <div id="tabsystem">
        <ul class="tabsystemHeaders">
            <li data-id="tabPageServer" title="Server" class="active">
                <span data-content="label.server_tab" class="title">Server<span>
            </li>
        </ul>
        <div class="tabsystemViewport">
            <div id="tabPageServer" class="tabPage">
                <div class="chatOutputContainer">
                    <div class="chatMessagesContainer">
                        <ul class="chatMessages">
                            <li data-content="manage_msg.loading_start">Loading...</li>
                        </ul>
                    </div>
                </div>
                <div class="chatFormContainer">
                    <form id="channelCreateForm" action="#">
                        <div class="formSection">
                            <h2 class="sectionHeader" data-content="label.channel_join_options"></h2>
                            <div class="inputContainer">
                                <label for="channelNameInput" data-content="label.channel_name">Channel name</label>
                                <input type="text" id="channelNameInput" required maxlength="30">
                            </div>
                            <div class="inputContainer">
                                <label for="channelPasswordInput" data-content="label.channel_password">Channel password</label>
                                <input type="text" id="channelPasswordInput" maxlength="20">
                            </div>
                        </div>
                        <div class="formSection">
                            <h2 class="sectionHeader" data-content="label.channel_creation_options"></h2>
                            <div class="inputContainer">
                                <input type="checkbox" id="channelFlagPublic">
                                <label for="channelFlagPublic" data-content="label.channel_flag_public">Hide joined users</label>
                            </div>
                            <div class="inputContainer">
                                <input type="checkbox" id="channelFlagIRC">
                                <label for="channelFlagIRC" data-content="label.channel_flag_irc">Mirror channel to IRC</label>
                            </div>
                        </div>
                        <div class="formSection">
                            <input type="submit" id="channelCreateSubmitButton">
                        </div>
                        <div class="formSection">
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>
'

TAB_PAGE = '
    <div class="tabPage">
        <div class="chatOutputContainer">
            <div class="chatMessagesContainer">
                <ul class="chatMessages">

                </ul>
            </div>
            <div class="chatUsersContainer">
                <div class="chatUsersCount">
                    <span class="title" data-content="label.current_number_of_players"></span>
                    <span class="value"></span>
                </div>
                <ul class="chatUsers players">

                </ul>
                <div class="chatChannelName">
                    <span class="title" data-content="label.irc_channel_name"></span>
                    <span class="value"></span>
                </div>
                <ul class="chatUsers irc">

                </ul>
            </div>
        </div>
        <div class="chatFormContainer">
            <form action="#" class="chatForm">
                <div class="formSection">
                    <input type="text" name="chatInput" class="chatInput">
                    <input type="submit" class="chatSubmitButton">
                </div>
                <div class="formSection right">
                    <button class="channelDeleteButton" data-content="label.button.delete_channel">Delete channel</button>
                    <button class="channelLeaveButton" data-content="label.button.leave_channel">Leave channel</button>
                    <button class="channelCloseButton" data-content="label.button.close_channel">Close</button>
                </div>
            </form>
        </div>
    </div>
'


module.exports = {
    TAB_SYSTEM
    TAB_PAGE
}
