import { Application } from "@hotwired/stimulus"
import PostFormController from "./post_form_controller"
import CommentFormController from "./comment_form_controller"
import PostController from "./post_controller"
import ReactionPickerController from "./reaction_picker_controller"
import FormValidationController from "./form_validation_controller"
import PostFormValidationController from "./post_form_validation_controller"
import UserSearchController from "./user_search_controller"
import FlashController from "./flash_controller"
import DropdownController from "./dropdown_controller"
import ConfirmDialogController from "./confirm_dialog_controller"
import NotificationPollingController from "./notification_polling_controller"
import NotificationBellController from "./notification_bell_controller"

const application = Application.start()

application.register("post-form", PostFormController)
application.register("comment-form", CommentFormController)
application.register("post", PostController)
application.register("reaction-picker", ReactionPickerController)
application.register("form-validation", FormValidationController)
application.register("post-form-validation", PostFormValidationController)
application.register("user-search", UserSearchController)
application.register("flash", FlashController)
application.register("dropdown", DropdownController)
application.register("confirm-dialog", ConfirmDialogController)
application.register("notification-polling", NotificationPollingController)
application.register("notification-bell", NotificationBellController)

export { application }
