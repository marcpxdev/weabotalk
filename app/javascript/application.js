// Configure Stimulus
import { Application } from "@hotwired/stimulus"
import PostFormController from "./controllers/post_form_controller"
import CommentFormController from "./controllers/comment_form_controller"
import PostController from "./controllers/post_controller"
import ReactionPickerController from "./controllers/reaction_picker_controller"
import FormValidationController from "./controllers/form_validation_controller"
import PostFormValidationController from "./controllers/post_form_validation_controller"
import UserSearchController from "./controllers/user_search_controller"
import FlashController from "./controllers/flash_controller"
import DropdownController from "./controllers/dropdown_controller"
import ConfirmDialogController from "./controllers/confirm_dialog_controller"
import NotificationPollingController from "./controllers/notification_polling_controller"
import NotificationBellController from "./controllers/notification_bell_controller"

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