let GridSelection = {
  mounted() {
    window.addEventListener('smgr:select-all', (event) => {
      let gridId = event.detail.gridId;
      let targetValue = event.target.checked;
      // Mirror the select-all checkbox to all checkboxes in the page
      for (const checkbox of document.getElementsByName(`${gridId}-selection`)) {
        checkbox.checked = targetValue;
      }
      this.pushEventTo(`#${gridId}`, 'select-all', { value: targetValue });

    });

    window.addEventListener('smgr:select-one', (event) => {
      let gridId = event.detail.gridId;
      let selectAllCheckbox = document.getElementById(`${gridId}-select-all`);
      let target = event.target;
      let targetValue = target.checked;
      let elements = document.getElementsByName(`${gridId}-selection`);
      // Compute a list of IDs from all checked checkboxes
      let checked = [...elements]
        .filter((element) => element.checked === true)
        .map((element) => element.value);
      // If the select-all checkbox is checked but the user is unchecking (i.e. de-selecting)
      // one of the rows, uncheck the select-all checkbox and send the current list of
      // checked row IDs to the backend
      if (selectAllCheckbox.checked === true && targetValue === false) {
        selectAllCheckbox.checked = false;
        this.pushEventTo(`#${gridId}`, 'select-many', { ids: checked });
        return;
      }

      this.pushEventTo(`#${gridId}`, 'select-one', { id: target.value, value: targetValue });
    });
  }
}

let InfiniteScroll = {
  loadMore(entries) {
    const target = entries[0];
    if (target.isIntersecting) {
      this.pushEvent("load_more", {});
    }
  },
  mounted() {
    this.observer = new IntersectionObserver(
      (entries) => this.loadMore(entries),
      {
        root: null, // window by default
        rootMargin: "400px",
        threshold: 0.1,
      }
    );
    this.observer.observe(this.el);
  },
  destroyed() {
    this.observer.unobserve(this.el);
  }
};

export { GridSelection, InfiniteScroll }
