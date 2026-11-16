pragma Singleton
import QtQuick

// "Is this item's own action in flight?" for list rows and detail pages, keyed the
// way ApiClient's busy lists are (containers by 12-character short id).
QtObject {
    function container(id) {
        return apiClient.busyContainerIds.indexOf(String(id).substring(0, 12)) >= 0
    }

    function image(id) {
        return apiClient.busyImageIds.indexOf(id) >= 0
    }

    function volume(name) {
        return apiClient.busyVolumeNames.indexOf(name) >= 0
    }
}
