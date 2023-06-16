let GridSelection = {
  mounted() {
    this.handleEvent("smgr:select-all", ({ gridId, value }) => {
      for (const checkbox of document.getElementsByName(`${gridId}-selection[]`)) {
        checkbox.checked = value;
      }
      for (const actionBtn of document.getElementsByName(`${gridId}-selection-action`)) {
        actionBtn.disabled = !value;
      }
    });
    this.handleEvent("smgr:select-some", ({ gridId }) => {
      let selectAllCheckbox = document.getElementById(`${gridId}-select-all`);
      let elements = document.getElementsByName(`${gridId}-selection[]`);
      // Compute a list of IDs from all checked checkboxes
      let checked = [...elements]
        .filter((element) => element.checked === true)
        .map((element) => element.value);
      // If the select-all checkbox is checked but the user is unchecking (i.e. de-selecting)
      // one of the rows, uncheck the select-all checkbox and send the current list of
      // checked row IDs to the backend
      if (selectAllCheckbox.checked === true && checked.length < elements.length) {
        selectAllCheckbox.checked = false;
      }
      for (const actionBtn of document.getElementsByName(`${gridId}-selection-action`)) {
        actionBtn.disabled = checked.length == 0;
      }

    });
    this.handleEvent("smgr:reset-selection", ({ gridId }) => {
      let selectAllCheckbox = document.getElementById(`${gridId}-select-all`);
      selectAllCheckbox.checked = false;
      for (const checkbox of document.getElementsByName(`${gridId}-selection[]`)) {
        checkbox.checked = false;
      }
      for (const actionBtn of document.getElementsByName(`${gridId}-selection-action`)) {
        actionBtn.disabled = true;
      }

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
